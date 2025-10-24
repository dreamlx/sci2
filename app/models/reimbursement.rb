class Reimbursement < ApplicationRecord
  # Constants
  STATUS_PENDING = 'pending'.freeze
  STATUS_PROCESSING = 'processing'.freeze
  STATUS_CLOSED = 'closed'.freeze
  STATUS_CLOSE_ALIAS = 'close'.freeze # Alias for backward compatibility

  STATUSES = [
    STATUS_PENDING,
    STATUS_PROCESSING,
    STATUS_CLOSED,
    STATUS_CLOSE_ALIAS
  ].freeze

  # Associations
  has_many :fee_details, foreign_key: 'document_number', primary_key: 'invoice_number', dependent: :destroy
  has_many :work_orders, dependent: :destroy
  has_many :audit_work_orders, -> { where(type: 'AuditWorkOrder') }, class_name: 'AuditWorkOrder'
  has_many :communication_work_orders, lambda {
    where(type: 'CommunicationWorkOrder')
  }, class_name: 'CommunicationWorkOrder'
  has_many :express_receipt_work_orders, lambda {
    where(type: 'ExpressReceiptWorkOrder')
  }, class_name: 'ExpressReceiptWorkOrder'
  has_many :operation_histories, foreign_key: 'document_number', primary_key: 'invoice_number', dependent: :destroy

  # 报销单分配关联
  has_many :assignments, class_name: 'ReimbursementAssignment', dependent: :destroy
  has_many :assignees, through: :assignments, source: :assignee
  has_one :active_assignment, -> { where(is_active: true) }, class_name: 'ReimbursementAssignment'
  has_one :current_assignee, through: :active_assignment, source: :assignee

  # Validations
  validates :invoice_number, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :is_electronic, inclusion: { in: [true, false] }

  # State Machine
  state_machine :status, initial: :pending do
    event :start_processing do
      transition pending: :processing
    end

    event :close_processing do
      transition processing: :closed
    end

    event :reopen_to_processing do
      transition closed: :processing
    end

    # Support backward compatibility for 'close' status
    state :close, value: STATUS_CLOSE_ALIAS
    event :mark_as_close do
      transition processing: :close
    end

    event :reopen_from_close do
      transition close: :processing
    end
  end

  # Scopes
  scope :pending, -> { where(status: STATUS_PENDING) }
  scope :processing, -> { where(status: STATUS_PROCESSING) }
  scope :closed, -> { where(status: STATUS_CLOSED) }
  scope :electronic, -> { where(is_electronic: true) }
  scope :non_electronic, -> { where(is_electronic: false) }
  scope :unassigned, -> { left_joins(:active_assignment).where(reimbursement_assignments: { id: nil }) }

  # Class methods for scopes (for shoulda-matchers compatibility)
  def self.pending
    where(status: STATUS_PENDING)
  end

  def self.processing
    where(status: STATUS_PROCESSING)
  end

  def self.closed
    where(status: STATUS_CLOSED)
  end

  def self.electronic
    where(is_electronic: true)
  end

  def self.non_electronic
    where(is_electronic: false)
  end

  # 获取分配给特定用户的报销单
  def self.assigned_to_user(user_id)
    joins(:assignments)
      .where(reimbursement_assignments: { assignee_id: user_id, is_active: true })
      .distinct
  end

  # 定义my_assignments scope作为assigned_to_user的别名
  # 这是为了向后兼容，因为dashboard和其他地方使用了scope=my_assignments参数
  # 推荐在新代码中使用assigned_to_user方法或assigned_to_me scope
  scope :my_assignments, ->(user_id) { assigned_to_user(user_id) }

  # 通知相关方法和查询范围

  # 检查是否有未查看的操作历史
  def has_unviewed_operation_histories?
    return true if last_viewed_operation_histories_at.nil?

    operation_histories.where('created_at > ?', last_viewed_operation_histories_at).exists?
  end

  # 检查是否有未查看的快递收单
  def has_unviewed_express_receipts?
    return true if last_viewed_express_receipts_at.nil?

    express_receipt_work_orders.where('created_at > ?', last_viewed_express_receipts_at).exists?
  end

  # 检查是否有任何未查看的记录
  def has_unviewed_records?
    has_unviewed_operation_histories? || has_unviewed_express_receipts?
  end

  # 标记操作历史为已查看
  def mark_operation_histories_as_viewed!
    update(last_viewed_operation_histories_at: Time.current)
  end

  # 标记快递收单为已查看
  def mark_express_receipts_as_viewed!
    update(last_viewed_express_receipts_at: Time.current)
  end

  # 标记所有记录为已查看
  def mark_all_as_viewed!
    update(
      last_viewed_operation_histories_at: Time.current,
      last_viewed_express_receipts_at: Time.current
    )
  end
  # === 新增：统一通知状态管理 ===

  # 检查是否有任何更新（操作历史或快递工单）
  def has_updates?
    operation_histories.exists? || express_receipt_work_orders.exists?
  end

  # 统一的通知状态检查方法
  def has_unread_updates?
    has_updates? && (last_viewed_at.nil? || (last_update_at && last_update_at > last_viewed_at))
  end

  # 计算最新更新时间
  def calculate_last_update_time
    times = []

    # 获取最新的操作记录时间
    latest_operation = operation_histories.maximum(:created_at)
    times << latest_operation if latest_operation

    # 获取最新的快递收单时间
    latest_express = express_receipt_work_orders.maximum(:created_at)
    times << latest_express if latest_express

    # 返回最新的时间，如果没有则返回更新时间
    times.max || updated_at
  end

  # 更新通知状态
  def update_notification_status!
    new_last_update_at = calculate_last_update_time
    new_has_updates = last_viewed_at.nil? || new_last_update_at > last_viewed_at

    update_columns(
      last_update_at: new_last_update_at,
      has_updates: new_has_updates
    )
  end

  # 标记为已查看（统一方法）
  def mark_as_viewed!
    update!(
      last_viewed_at: Time.current,
      has_updates: false,
      # 保持向后兼容
      last_viewed_operation_histories_at: Time.current,
      last_viewed_express_receipts_at: Time.current
    )
  end

  # 查询范围：有未查看操作历史的报销单
  scope :with_unviewed_operation_histories, lambda {
    where('last_viewed_operation_histories_at IS NULL OR EXISTS (SELECT 1 FROM operation_histories WHERE operation_histories.document_number = reimbursements.invoice_number AND operation_histories.created_at > reimbursements.last_viewed_operation_histories_at)')
  }

  # 查询范围：有未查看快递收单的报销单
  scope :with_unviewed_express_receipts, lambda {
    where('last_viewed_express_receipts_at IS NULL OR EXISTS (SELECT 1 FROM work_orders WHERE work_orders.reimbursement_id = reimbursements.id AND work_orders.type = ? AND work_orders.created_at > reimbursements.last_viewed_express_receipts_at)', 'ExpressReceiptWorkOrder')
  }

  # === 新增：查询范围 ===

  # 有未读更新的报销单（替换原有的with_unviewed_records）
  scope :with_unread_updates, lambda {
    where(has_updates: true)
      .where('last_viewed_at IS NULL OR last_update_at > last_viewed_at')
  }

  # 分配给用户且有未读更新的报销单
  scope :assigned_with_unread_updates, lambda { |user_id|
    assigned_to_user(user_id).with_unread_updates
  }

  # 按通知状态排序（有更新的优先，然后按最新更新时间倒序）
  scope :ordered_by_notification_status, lambda {
    order(
      Arel.sql('has_updates DESC, last_update_at DESC NULLS LAST')
    )
  }

  # 查询范围：有任何未查看记录的报销单
  scope :with_unviewed_records, lambda {
    with_unviewed_operation_histories.or(with_unviewed_express_receipts)
  }

  # ActiveAdmin configuration
  def self.ransackable_attributes(_auth_object = nil)
    %w[id invoice_number document_name applicant applicant_id company department
       receipt_status receipt_date submission_date amount is_electronic status
       external_status approval_date approver_name related_application_number
       accounting_date document_tags created_at updated_at current_assignee_id
       erp_current_approval_node erp_current_approver erp_flexible_field_2
       erp_node_entry_time erp_first_submitted_at erp_flexible_field_8]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[fee_details work_orders audit_work_orders communication_work_orders
       express_receipt_work_orders operation_histories active_assignment current_assignee]
  end

  # 定义可用于Ransack搜索的scope
  def self.ransackable_scopes(_auth_object = nil)
    %w[with_unviewed_records with_unread_updates assigned_with_unread_updates]
  end

  # Custom ransacker for current_assignee_id
  ransacker :current_assignee_id do
    Arel.sql('(SELECT assignee_id FROM reimbursement_assignments WHERE reimbursement_assignments.reimbursement_id = reimbursements.id AND reimbursement_assignments.is_active = true LIMIT 1)')
  end

  # Instance methods

  # Check if this reimbursement is in pending status
  def pending?
    status == STATUS_PENDING
  end

  # Check if this reimbursement is in processing status
  def processing?
    status == STATUS_PROCESSING
  end

  # Check if this reimbursement is in closed status
  def closed?
    status == STATUS_CLOSED
  end

  # Check if this reimbursement is electronic
  def electronic?
    !!is_electronic
  end

  # Check if all fee details are verified
  def all_fee_details_verified?
    fee_details.any? && fee_details.where.not(verification_status: FeeDetail::VERIFICATION_STATUS_VERIFIED).none?
  end

  # Check if any fee details are problematic
  def any_fee_details_problematic?
    fee_details.problematic.exists?
  end

  # Check if this reimbursement can be closed
  def can_be_closed?
    processing? && all_fee_details_verified?
  end

  # Close this reimbursement
  def close!
    return unless can_be_closed?

    mark_as_close! # Use state machine event

    # If cannot be closed, do nothing (legacy behavior)
  end

  # Alternative close method with different naming convention for backward compatibility
  def mark_as_close!
    close_processing! # Use state machine event
  end

  # Check if this reimbursement can be closed (alternative naming convention)
  def can_mark_as_close?
    can_be_closed?
  end

  # Check if this reimbursement is in closed status (handles both 'close' and 'closed')
  def closed?
    [STATUS_CLOSED, STATUS_CLOSE_ALIAS].include?(status)
  end

  # Update the status based on fee details
  def update_status_based_on_fee_details!
    case status
    when STATUS_PROCESSING
      close! if all_fee_details_verified?
    when STATUS_CLOSED
      reopen_to_processing! if any_fee_details_problematic?
    end
    true
  end

  # Reopen a closed reimbursement to processing
  def reopen_to_processing!
    return false unless closed?

    update(status: STATUS_PROCESSING)
  end

  # Manual status change with override protection
  def manual_status_change!(new_status, user = nil)
    update!(
      status: new_status,
      manual_override: true,
      manual_override_at: Time.current
    )
    Rails.logger.info "Manual status change by #{user&.email || 'system'}: #{invoice_number} -> #{new_status}"
  end

  # Reset manual override flag
  def reset_manual_override!
    update!(
      manual_override: false,
      manual_override_at: nil
    )
  end

  # Check if external status should force closure
  def should_close_based_on_external_status?
    return false unless external_status.present?

    external_status.match?(/已付款|待付款/)
  end

  # Check if reimbursement has active work orders
  def has_active_work_orders?
    audit_work_orders.exists? || communication_work_orders.exists?
  end

  # Determine internal status based on business rules
  def determine_internal_status_from_external(external_status_value)
    return status if manual_override?

    if external_status_value&.match?(/已付款|待付款/)
      STATUS_CLOSED
    elsif has_active_work_orders?
      STATUS_PROCESSING
    else
      STATUS_PENDING
    end
  end

  # Check if work orders can be created for this reimbursement
  def can_create_work_orders?
    !closed?
  end

  # Mark this reimbursement as received
  def mark_as_received(received_date = nil)
    update(
      receipt_status: 'received',
      receipt_date: received_date || Time.current
    )
  end

  # Get the meeting type context for this reimbursement
  # This is used to determine which fee types to show in the dropdown
  def meeting_type_context
    # Logic to determine if this is a personal or academic expense
    # This is a simplified example - you would need more sophisticated logic based on your data
    if document_name.to_s.include?('个人') || document_name.to_s.include?('交通') || document_name.to_s.include?('电话')
      return '个人'
    end
    if document_name.to_s.include?('学术') || document_name.to_s.include?('会议') || document_name.to_s.include?('论坛')
      return '学术论坛'
    end

    # Default
    '个人'
  end

  # === 回调方法：自动更新通知状态 ===

  after_update :update_notification_status_if_needed

  private

  def update_notification_status_if_needed
    # 如果相关字段发生变化，重新计算通知状态
    if saved_change_to_last_viewed_operation_histories_at? ||
       saved_change_to_last_viewed_express_receipts_at?
      update_notification_status!
    end
  end

  # === 保持向后兼容的方法 ===

  # 保留原有方法以确保向后兼容
  alias has_unviewed_records? has_unread_updates?
end
