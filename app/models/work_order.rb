# app/models/work_order.rb
class WorkOrder < ApplicationRecord
  # 显式定义 STI 列
  self.inheritance_column = :type
  
  # 关联
  belongs_to :reimbursement
  belongs_to :creator, class_name: 'AdminUser', foreign_key: 'creator_id', optional: true
  
  # ADDED: Common associations for problem type and description
  belongs_to :problem_type, optional: true
  belongs_to :problem_description, optional: true
  
  # 多态关联
  
  has_many :work_order_status_changes, as: :work_order, dependent: :destroy
  
  # 新的多对多关联
  has_many :work_order_fee_details, as: :work_order, dependent: :destroy # 'as: :work_order' 是多态的关键
  has_many :fee_details, through: :work_order_fee_details

  # 验证
  validates :reimbursement_id, presence: true
  validates :type, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending processing approved rejected] }
  validates :audit_date, presence: true, if: -> { status.in?(%w[approved rejected]) && respond_to?(:audit_date) && audit_date.blank? }
  
  # Update shared validations to depend on status == 'rejected'
  validates :problem_type_id, presence: true, if: -> { (is_a?(AuditWorkOrder) || is_a?(CommunicationWorkOrder)) && status == 'rejected' }
  validates :problem_description_id, presence: true, if: -> { (is_a?(AuditWorkOrder) || is_a?(CommunicationWorkOrder)) && status == 'rejected' }
  validates :audit_comment, presence: true, if: -> { (is_a?(AuditWorkOrder) || is_a?(CommunicationWorkOrder)) && status == 'rejected' }
  
  # 添加虚拟属性以接收表单提交的fee_detail_ids
  attr_accessor :submitted_fee_detail_ids # 更清晰的命名以区分于实际关联的 fee_detail_ids
  
  # 初始化fee_detail_ids为空数组
  def fee_detail_ids
    @fee_detail_ids ||= []
  end
  
  # 回调
  after_commit :record_status_change, on: [:create, :update], if: -> { saved_change_to_status? }
  after_create :update_reimbursement_status_on_create
  before_validation :set_status_based_on_processing_opinion
  after_save :process_submitted_fee_details
  after_save :sync_fee_details_verification_status_with_work_order_status,
             if: -> { saved_change_to_status? && status.in?(['approved', 'rejected']) }

  # --- 状态机 (ONLY status) ---
  state_machine :status, initial: :pending do
    state :pending
    state :processing
    state :approved
    state :rejected

    event :start_processing do
      transition [:pending, :approved, :rejected] => :processing
    end
    
    event :force_approve do
      transition all => :approved
    end

    event :force_reject do
      transition all => :rejected
    end
  end

  # --- Scopes (ONLY status based) ---
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  # 类方法
  def self.sti_name
    name
  end
  
  # 实例方法
  public
  
  def record_status_change
    # 获取事务中的状态变更详情
    status_change = previous_changes['status']
    return unless status_change # 确保状态确实发生了变化
    
    old_status, new_status = status_change
    
    # 使用 build 和 save 而不是 create! 以便于调试
    status_change = work_order_status_changes.build(
      work_order_type: self.class.name, # 使用 class.name 而不是 sti_name
      from_status: old_status,
      to_status: new_status,
      changed_at: Time.current
    )
    
    # 只有在 Current.admin_user 或 creator 存在时才设置 changer
    if Current.admin_user.present?
      status_change.changer = Current.admin_user
    elsif creator.present?
      status_change.changer = creator
    end
    
    # 使用 save 而不是 save! 以避免异常
    unless status_change.save
      Rails.logger.error "Failed to save WorkOrderStatusChange: #{status_change.errors.full_messages.join(', ')}"
    end
  rescue => e
    Rails.logger.error "Error in record_status_change: #{e.message}"
  end
  
  def update_reimbursement_status_on_create
    # 当创建审核工单或沟通工单时触发报销单状态更新
    if self.is_a?(AuditWorkOrder) || self.is_a?(CommunicationWorkOrder)
      reimbursement.start_processing! if reimbursement.pending?
    end
  rescue StateMachines::InvalidTransition => e
    Rails.logger.error "Error updating reimbursement status from WorkOrder ##{id} creation: #{e.message}"
  end
  
  def process_submitted_fee_details
    # 仅当 @submitted_fee_detail_ids 存在时执行 (由 controller 设置)
    return unless @submitted_fee_detail_ids 

    # 将提交的 ID 转换为整数数组，并移除0或空值
    current_ids = self.fee_detail_ids # 当前实际关联的 FeeDetail ID 列表
    new_ids = @submitted_fee_detail_ids.map(&:to_i).reject(&:zero?).uniq

    # 计算需要添加和移除的关联
    ids_to_add = new_ids - current_ids
    ids_to_remove = current_ids - new_ids

    # 添加新的关联
    ids_to_add.each do |fee_detail_id|
      # 可以添加 FeeDetail.exists?(fee_detail_id) 的检查
      self.work_order_fee_details.create(fee_detail_id: fee_detail_id)
    end

    # 移除不再需要的关联
    if ids_to_remove.any?
      self.work_order_fee_details.where(fee_detail_id: ids_to_remove).destroy_all
    end
    
    # 清理，防止下次保存时意外执行
    @submitted_fee_detail_ids = nil 
  end

  def associated_fee_details
    self.fee_details # 直接使用新建的 has_many :fee_details 关联
  end
  
  def update_associated_fee_details_status(target_verification_status)
    # This method was previously triggered by resolution change.
    # We might need to trigger it differently now, perhaps when status changes to approved/rejected?
    # Or maybe remove it if the logic is now handled elsewhere or not needed?
    # For now, let's keep the method but remove the callback that triggers it.
    Rails.logger.info "WorkOrder ##{id}: Updating associated fee details to #{target_verification_status}"
    
    # Ensure the target status is valid
    valid_target_statuses = [
      FeeDetail::VERIFICATION_STATUS_PENDING,
      FeeDetail::VERIFICATION_STATUS_VERIFIED,
      FeeDetail::VERIFICATION_STATUS_PROBLEMATIC
    ]
    unless valid_target_statuses.include?(target_verification_status)
      Rails.logger.error "WorkOrder ##{id}: Invalid target_verification_status #{target_verification_status} for fee details."
      return
    end
    
    details_to_update = associated_fee_details
    Rails.logger.info "WorkOrder ##{id}: Found #{details_to_update.count} fee details to update."
    
    details_to_update.find_each do |fee_detail|
      if fee_detail.verification_status != target_verification_status
        Rails.logger.info "WorkOrder ##{id}: Updating FeeDetail ##{fee_detail.id} from #{fee_detail.verification_status} to #{target_verification_status}"
        unless fee_detail.update(verification_status: target_verification_status)
          Rails.logger.error "WorkOrder ##{id}: Failed to update FeeDetail ##{fee_detail.id}: #{fee_detail.errors.full_messages.join(', ')}"
        end
      else
        Rails.logger.info "WorkOrder ##{id}: FeeDetail ##{fee_detail.id} already in state #{target_verification_status}. Skipping."
      end
    end
  rescue => e
    Rails.logger.error "WorkOrder ##{id}: Error in update_associated_fee_details_status: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  # ActiveAdmin 配置
  def self.ransackable_attributes(auth_object = nil)
    # Common fields + subclass-specific fields. Ensure 'resolution' and common status fields are here.
    # Added 'processing_opinion', 'audit_comment', 'audit_date' as common searchable fields.
    %w[id reimbursement_id type status processing_opinion audit_comment audit_date created_by created_at updated_at] + subclass_ransackable_attributes
  end
  
  # 子类的占位方法
  def self.subclass_ransackable_attributes
    []
  end
  
  def self.ransackable_associations(auth_object = nil)
    # Common associations + subclass-specific associations
    %w[reimbursement creator fee_details problem_type problem_description] + subclass_ransackable_associations
  end

  def self.subclass_ransackable_associations
    []
  end

  # Refactor set_status_based_on_processing_opinion
  def set_status_based_on_processing_opinion
    return unless self.is_a?(AuditWorkOrder) || self.is_a?(CommunicationWorkOrder)
    return unless processing_opinion_changed? || (new_record? && processing_opinion.present?) # Only run if opinion changed or on create

    case processing_opinion
    when nil, ""
      # If opinion is cleared, maybe reset status to processing if currently approved/rejected?
      if status.in?(%w[approved rejected])
        # self.status = "processing" # Revisit this logic based on desired behavior
      end
    when "可以通过", "审核通过"
      self.status = "approved" # Directly set status
      self.audit_date = Time.current if self.respond_to?(:audit_date=) && self.audit_date.blank?
    when "无法通过", "否决"
      self.status = "rejected" # Directly set status
      self.audit_date = Time.current if self.respond_to?(:audit_date=) && self.audit_date.blank?
    else
      # Any other non-empty opinion likely means processing should start or continue
      self.status = "processing" if self.pending?
    end
  rescue => e
    Rails.logger.error "无法基于处理意见更新状态 (WorkOrder ##{id}): #{e.message}"
  end

  private # Ensure this is private if it's not meant to be public API

  def sync_fee_details_verification_status_with_work_order_status
    return unless self.is_a?(AuditWorkOrder) || self.is_a?(CommunicationWorkOrder)

    target_verification_status = nil
    if status == 'approved'
      target_verification_status = FeeDetail::VERIFICATION_STATUS_VERIFIED
    elsif status == 'rejected'
      target_verification_status = FeeDetail::VERIFICATION_STATUS_PROBLEMATIC
    end

    if target_verification_status
      Rails.logger.info "WorkOrder ##{id} (status: #{status}): Syncing fee details to #{target_verification_status}."
      update_associated_fee_details_status(target_verification_status)
    else
      Rails.logger.info "WorkOrder ##{id} (status: #{status}): No fee detail status sync needed for this status."
    end
  rescue NameError => e
    # Catch NameError specifically if FeeDetail constants are not loaded
    Rails.logger.error "WorkOrder ##{id}: Error syncing fee details - FeeDetail constants not loaded? #{e.message}"
  rescue => e
    Rails.logger.error "WorkOrder ##{id}: Error in sync_fee_details_verification_status_with_work_order_status: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  public
  def completed?
    completed == true
  end
end