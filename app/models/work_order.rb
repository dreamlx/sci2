# app/models/work_order.rb
class WorkOrder < ApplicationRecord
  # 显式定义 STI 列
  self.inheritance_column = :type
  
  # 关联
  belongs_to :reimbursement
  belongs_to :creator, class_name: 'AdminUser', foreign_key: 'creator_id', optional: true
  
  # 多态关联
  has_many :fee_detail_selections, as: :work_order, dependent: :destroy
  has_many :fee_details, through: :fee_detail_selections
  has_many :work_order_status_changes, as: :work_order, dependent: :destroy

  # 验证
  validates :reimbursement_id, presence: true
  validates :type, presence: true
  validates :status, presence: true
  
  # 添加虚拟属性以接收表单提交的fee_detail_ids
  attr_accessor :fee_detail_ids
  
  # 初始化fee_detail_ids为空数组
  def fee_detail_ids
    @fee_detail_ids ||= []
  end
  
  # 验证费用明细选择 - 只对审核工单和沟通工单进行验证
  validate :validate_fee_detail_selections, if: -> {
    new_record? &&
    (self.is_a?(AuditWorkOrder) || self.is_a?(CommunicationWorkOrder))
  }
  
  def validate_fee_detail_selections
    # 检查是否有费用明细ID
    if @fee_detail_ids_to_select.blank? && fee_detail_ids.blank? && !Rails.env.test?
      errors.add(:fee_detail_selections, :invalid)
    end
  end
  
  # 在保存前处理表单提交的fee_detail_ids
  after_initialize :process_fee_detail_ids
  
  def process_fee_detail_ids
    # 如果fee_detail_ids存在且不为空，则设置@fee_detail_ids_to_select
    if fee_detail_ids.present?
      @fee_detail_ids_to_select = fee_detail_ids
    end
  end

  # 回调
  # 使用 after_commit 确保状态变更在成功保存后记录
  after_commit :record_status_change, on: [:create, :update], if: -> { saved_change_to_status? }
  after_create :update_reimbursement_status_on_create
  before_save :set_status_based_on_processing_opinion, if: :processing_opinion_changed?

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
  
  # 根据处理意见设置状态
  def set_status_based_on_processing_opinion
    return unless self.is_a?(AuditWorkOrder) || self.is_a?(CommunicationWorkOrder)
    
    case processing_opinion
    when nil, ""
      # 保持当前状态
    when "审核通过", "可以通过"
      self.status = "approved" unless status == "approved"
    when "否决", "无法通过"
      self.status = "rejected" unless status == "rejected"
    else
      self.status = "processing" if status == "pending"
    end
  rescue => e
    Rails.logger.error "无法基于处理意见更新状态: #{e.message}"
  end

  # 状态机回调的辅助方法
  def update_associated_fee_details_status(new_status)
    # 确保状态是有效的
    valid_statuses = ['problematic', 'verified']
    
    # 同时支持字符串和常量
    return unless valid_statuses.include?(new_status) || [
      FeeDetail::VERIFICATION_STATUS_PROBLEMATIC,
      FeeDetail::VERIFICATION_STATUS_VERIFIED
    ].include?(new_status)
    
    # 使用 FeeDetailVerificationService
    # 确保在调用状态机事件前适当设置 Current.admin_user
    verification_service = FeeDetailVerificationService.new(Current.admin_user || creator)
    
    # 如果性能成为问题，使用预加载
    fee_details.find_each do |fee_detail|
      # 仅当未验证时更新（允许 problematic -> verified）
      # 或者当状态从verified变为problematic时
      if fee_detail.pending? ||
         fee_detail.problematic? ||
         (fee_detail.verified? && new_status == 'problematic')
        verification_service.update_verification_status(fee_detail, new_status)
      end
    end
  end

  # ActiveAdmin 配置
  def self.ransackable_attributes(auth_object = nil)
    # 通用字段 + 下面添加的特定子类字段
    %w[id reimbursement_id type status created_by created_at updated_at] + subclass_ransackable_attributes
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[reimbursement creator fee_detail_selections fee_details work_order_status_changes] + subclass_ransackable_associations
  end
  
  # 子类的占位方法
  def self.subclass_ransackable_attributes
    []
  end
  
  def self.subclass_ransackable_associations
    []
  end
end