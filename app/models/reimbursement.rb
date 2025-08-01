class Reimbursement < ApplicationRecord
  # Constants
  STATUS_PENDING = 'pending'.freeze
  STATUS_PROCESSING = 'processing'.freeze
  STATUS_CLOSED = 'closed'.freeze
  
  STATUSES = [
    STATUS_PENDING,
    STATUS_PROCESSING,
    STATUS_CLOSED
  ].freeze
  
  # Associations
  has_many :fee_details, foreign_key: 'document_number', primary_key: 'invoice_number', dependent: :destroy
  has_many :work_orders, dependent: :destroy
  has_many :audit_work_orders, -> { where(type: 'AuditWorkOrder') }, class_name: 'AuditWorkOrder'
  has_many :communication_work_orders, -> { where(type: 'CommunicationWorkOrder') }, class_name: 'CommunicationWorkOrder'
  has_many :express_receipt_work_orders, -> { where(type: 'ExpressReceiptWorkOrder') }, class_name: 'ExpressReceiptWorkOrder'
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
  
  # 查询范围：有未查看操作历史的报销单
  scope :with_unviewed_operation_histories, -> {
    where('last_viewed_operation_histories_at IS NULL OR EXISTS (SELECT 1 FROM operation_histories WHERE operation_histories.document_number = reimbursements.invoice_number AND operation_histories.created_at > reimbursements.last_viewed_operation_histories_at)')
  }
  
  # 查询范围：有未查看快递收单的报销单
  scope :with_unviewed_express_receipts, -> {
    where('last_viewed_express_receipts_at IS NULL OR EXISTS (SELECT 1 FROM work_orders WHERE work_orders.reimbursement_id = reimbursements.id AND work_orders.type = ? AND work_orders.created_at > reimbursements.last_viewed_express_receipts_at)', 'ExpressReceiptWorkOrder')
  }
  
  # 查询范围：有任何未查看记录的报销单
  scope :with_unviewed_records, -> {
    with_unviewed_operation_histories.or(with_unviewed_express_receipts)
  }
  
  # ActiveAdmin configuration
  def self.ransackable_attributes(auth_object = nil)
    %w[id invoice_number document_name applicant applicant_id company department
       receipt_status receipt_date submission_date amount is_electronic status
       external_status approval_date approver_name related_application_number
       accounting_date document_tags created_at updated_at current_assignee_id
       erp_current_approval_node erp_current_approver erp_flexible_field_2
       erp_node_entry_time erp_first_submitted_at erp_flexible_field_8]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[fee_details work_orders audit_work_orders communication_work_orders
       express_receipt_work_orders operation_histories active_assignment current_assignee]
  end
  
  # 定义可用于Ransack搜索的scope
  def self.ransackable_scopes(auth_object = nil)
    %w[with_unviewed_records]
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
    is_electronic
  end
  
  # Check if all fee details are verified
  def all_fee_details_verified?
    fee_details.count > 0 && fee_details.where.not(verification_status: FeeDetail::VERIFICATION_STATUS_VERIFIED).count == 0
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
    return false unless can_be_closed?
    update(status: STATUS_CLOSED)
  end
  
  # Update the status based on fee details
  def update_status_based_on_fee_details!
    if processing?
      # If all fee details are verified, close the reimbursement
      if all_fee_details_verified?
        close!
      end
    elsif closed?
      # If any fee detail is problematic, reopen the reimbursement
      if any_fee_details_problematic?
        reopen_to_processing!
      end
    end
    
    true
  end
  
  # Reopen a closed reimbursement to processing
  def reopen_to_processing!
    return false unless closed?
    update(status: STATUS_PROCESSING)
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
    return "个人" if document_name.to_s.include?("个人") || document_name.to_s.include?("交通") || document_name.to_s.include?("电话")
    return "学术论坛" if document_name.to_s.include?("学术") || document_name.to_s.include?("会议") || document_name.to_s.include?("论坛")
    
    # Default
    "个人"
  end
end