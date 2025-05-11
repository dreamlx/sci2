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
  validates :resolution, presence: true, inclusion: { in: %w[pending approved rejected] }
  validates :audit_date, presence: true, if: -> { status.in?(%w[approved rejected]) && respond_to?(:audit_date) }
  
  # Common validation for problem_type_id and problem_description_id when resolution is rejected
  # This can now be in the base class as the associations are defined here.
  validates :problem_type_id, presence: true, if: -> { (is_a?(AuditWorkOrder) || is_a?(CommunicationWorkOrder)) && resolution == 'rejected' }
  validates :problem_description_id, presence: true, if: -> { (is_a?(AuditWorkOrder) || is_a?(CommunicationWorkOrder)) && resolution == 'rejected' }
  
  # 添加虚拟属性以接收表单提交的fee_detail_ids
  attr_accessor :submitted_fee_detail_ids # 更清晰的命名以区分于实际关联的 fee_detail_ids
  
  # 初始化fee_detail_ids为空数组
  def fee_detail_ids
    @fee_detail_ids ||= []
  end
  
  # 回调
  # 使用 after_commit 确保状态变更在成功保存后记录
  after_commit :record_status_change, on: [:create, :update], if: -> { saved_change_to_status? }
  after_create :update_reimbursement_status_on_create
  before_save :set_status_based_on_resolution
  before_validation :ensure_resolution_is_pending_if_nil
  
  # 回调，在保存后处理提交的 fee_detail_ids
  # 使用 after_save 确保工单本身已保存，ID可用
  after_save :process_submitted_fee_details

  # --- 状态机 (移自 AuditWorkOrder) ---
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

  state_machine :resolution, initial: :pending do
    state :pending
    state :approved
    state :rejected

    event :approve do
      transition [:pending, :rejected] => :approved
    end

    event :reject do
      transition [:pending, :approved] => :rejected
    end
    
    event :reset_resolution do
        transition [:approved, :rejected] => :pending
    end
  end

  # --- ADDED: Common scopes based on status and resolution state machines ---
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  # For status-based approved/rejected, if needed directly (though resolution is primary driver)
  scope :status_approved, -> { where(status: 'approved') }
  scope :status_rejected, -> { where(status: 'rejected') }
  
  # For resolution-based approved/rejected (more common for business logic)
  scope :resolution_approved, -> { where(resolution: 'approved') }
  scope :resolution_rejected, -> { where(resolution: 'rejected' ) }
  scope :resolution_pending, -> { where(resolution: 'pending') } # Scope for pending resolution
  # --- END ADDED SCOPES ---

  # Scopes for ActiveAdmin and general use
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :approved, -> { where(status: 'approved') } # For status 'approved'
  scope :rejected, -> { where(status: 'rejected') } # For status 'rejected'

  # More specific scopes (already existing, kept for clarity or direct use)
  scope :status_pending, -> { where(status: 'pending') }
  scope :status_processing, -> { where(status: 'processing') }
  scope :status_approved, -> { where(status: 'approved') }
  scope :status_rejected, -> { where(status: 'rejected') }

  scope :resolution_pending, -> { where(resolution: 'pending') }
  scope :resolution_approved, -> { where(resolution: 'approved') }
  scope :resolution_rejected, -> { where(resolution: 'rejected') }

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
  
  def ensure_resolution_is_pending_if_nil
    # Only set to pending if it's nil and if the work order type uses resolution
    if (self.is_a?(AuditWorkOrder) || self.is_a?(CommunicationWorkOrder)) && resolution.nil?
      self.resolution = 'pending'
    end
  end

  def set_status_based_on_resolution
    # Only apply this logic for types that use this status/resolution flow
    return unless self.is_a?(AuditWorkOrder) || self.is_a?(CommunicationWorkOrder)

    if resolution_changed? && (resolution_was != self.resolution) # Ensure resolution actually changed
      new_status_val = case self.resolution
                       when 'approved' then 'approved'
                       when 'rejected' then 'rejected'
                       else self.status # Should not happen if resolution is always one of the two
                       end
      
      if new_status_val.in?(%w[approved rejected]) && self.status != new_status_val
        self.status = new_status_val
        self.audit_date ||= Time.current if self.respond_to?(:audit_date=)
      elsif self.resolution == 'pending' && self.status.in?(%w[approved rejected])
        # If resolution is reset to pending (e.g. opinion cleared), move status to processing
        self.status = 'processing'
      end
    end
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

  # 辅助方法，获取当前工单关联的所有费用明细
  # set_status_based_on_processing_opinion 和 update_associated_fee_details_status 会用到
  def associated_fee_details
    self.fee_details # 直接使用新建的 has_many :fee_details 关联
  end
  
  # update_associated_fee_details_status 方法现在可以正确工作，
  #因为它调用的 associated_fee_details 将返回正确的 FeeDetail 集合
  def update_associated_fee_details_status(new_status)
    Rails.logger.info "WorkOrder ##{id}: 进入 update_associated_fee_details_status 方法，new_status = #{new_status}"
    Rails.logger.info "WorkOrder ##{id}: 调用栈: #{caller[0..5].join("\n")}"
    Rails.logger.info "WorkOrder ##{id}: 开始更新关联的费用明细状态为 #{new_status}"
    
    # 确保状态是有效的
    valid_statuses = ['problematic', 'verified']
    
    # 同时支持字符串和常量
    unless valid_statuses.include?(new_status) || [
      FeeDetail::VERIFICATION_STATUS_PROBLEMATIC,
      FeeDetail::VERIFICATION_STATUS_VERIFIED
    ].include?(new_status)
      Rails.logger.error "WorkOrder ##{id}: 无效的状态 #{new_status}"
      return
    end
    
    # 使用辅助方法获取关联的费用明细
    details_to_update = associated_fee_details
    Rails.logger.info "WorkOrder ##{id}: 找到 #{details_to_update.count} 个关联的费用明细来更新状态"
    
    # 直接更新费用明细状态，不再使用 FeeDetailVerificationService
    # 也不再区分测试环境和生产环境
    details_to_update.find_each do |fee_detail|
      Rails.logger.info "WorkOrder ##{id}: 处理费用明细 ##{fee_detail.id}，当前状态: #{fee_detail.verification_status}"
      
      # 仅当未验证时更新（允许 problematic -> verified）
      # 或者当状态从verified变为problematic时
      if fee_detail.pending? ||
         fee_detail.problematic? ||
         (fee_detail.verified? && new_status == 'problematic')
        Rails.logger.info "WorkOrder ##{id}: 直接更新费用明细 ##{fee_detail.id} 状态为 #{new_status}"
        result = fee_detail.update(verification_status: new_status)
        Rails.logger.info "WorkOrder ##{id}: 更新费用明细 ##{fee_detail.id} 结果: #{result ? '成功' : '失败'}"
        if !result
          Rails.logger.error "WorkOrder ##{id}: 更新费用明细 ##{fee_detail.id} 失败: #{fee_detail.errors.full_messages.join(', ')}"
        end
      else
        Rails.logger.info "WorkOrder ##{id}: 跳过费用明细 ##{fee_detail.id}，不符合更新条件"
      end
    end
  rescue => e
    Rails.logger.error "WorkOrder ##{id}: 更新关联的费用明细状态时出错: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  # ActiveAdmin 配置
  def self.ransackable_attributes(auth_object = nil)
    # Common fields + subclass-specific fields. Ensure 'resolution' and common status fields are here.
    # Added 'processing_opinion', 'audit_comment', 'audit_date' as common searchable fields.
    %w[id reimbursement_id type status resolution processing_opinion audit_comment audit_date created_by created_at updated_at] + subclass_ransackable_attributes
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
end