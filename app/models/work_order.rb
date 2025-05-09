# app/models/work_order.rb
class WorkOrder < ApplicationRecord
  # 显式定义 STI 列
  self.inheritance_column = :type
  
  # 关联
  belongs_to :reimbursement
  belongs_to :creator, class_name: 'AdminUser', foreign_key: 'creator_id', optional: true
  
  # 多态关联
  
  has_many :work_order_status_changes, as: :work_order, dependent: :destroy
  
  # 新的多对多关联
  has_many :work_order_fee_details, as: :work_order, dependent: :destroy # 'as: :work_order' 是多态的关键
  has_many :fee_details, through: :work_order_fee_details

  # 验证
  validates :reimbursement_id, presence: true
  validates :type, presence: true
  validates :status, presence: true
  
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
  before_save :set_status_based_on_processing_opinion, if: :processing_opinion_changed?
  
  # 回调，在保存后处理提交的 fee_detail_ids
  # 使用 after_save 确保工单本身已保存，ID可用
  after_save :process_submitted_fee_details

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
    Rails.logger.info "WorkOrder ##{id}: 进入 set_status_based_on_processing_opinion 方法"
    Rails.logger.info "WorkOrder ##{id}: processing_opinion_changed? = #{processing_opinion_changed?}"
    Rails.logger.info "WorkOrder ##{id}: processing_opinion = #{processing_opinion.inspect}"
    Rails.logger.info "WorkOrder ##{id}: processing_opinion_was = #{processing_opinion_was.inspect}" if respond_to?(:processing_opinion_was)
    
    return unless self.is_a?(AuditWorkOrder) || self.is_a?(CommunicationWorkOrder)
    
    Rails.logger.info "WorkOrder ##{id}: 开始处理处理意见 '#{processing_opinion}'"
    Rails.logger.info "WorkOrder ##{id}: 当前状态 #{status}"
    
    old_status = status
    old_processing_opinion = processing_opinion_was if respond_to?(:processing_opinion_was)
    
    Rails.logger.info "WorkOrder ##{id}: 处理意见从 '#{old_processing_opinion}' 变更为 '#{processing_opinion}'"
    
    case processing_opinion
    when nil, ""
      # 保持当前状态
      Rails.logger.info "WorkOrder ##{id}: 处理意见为空，保持当前状态"
    when "审核通过", "可以通过"
      if status != "approved"
        self.status = "approved"
        Rails.logger.info "WorkOrder ##{id}: 设置状态为 approved"
      end
      # 如果是审核工单，设置审核结果
      if self.is_a?(AuditWorkOrder)
        self.audit_result = 'approved'
        self.audit_date = Time.current
        Rails.logger.info "WorkOrder ##{id}: 设置审核结果为 approved，审核日期为 #{audit_date}"
      end
    when "否决", "无法通过"
      if status != "rejected"
        self.status = "rejected"
        Rails.logger.info "WorkOrder ##{id}: 设置状态为 rejected"
      end
      # 如果是审核工单，设置审核结果
      if self.is_a?(AuditWorkOrder)
        self.audit_result = 'rejected'
        self.audit_date = Time.current
        Rails.logger.info "WorkOrder ##{id}: 设置审核结果为 rejected，审核日期为 #{audit_date}"
      end
    else
      if status == "pending"
        self.status = "processing"
        Rails.logger.info "WorkOrder ##{id}: 设置状态为 processing"
      end
    end
    
    # 无论状态是否变化，都更新关联的费用明细状态
    Rails.logger.info "WorkOrder ##{id}: 处理意见为 '#{processing_opinion}'，更新关联的费用明细状态"
    
    case processing_opinion
    when "审核通过", "可以通过"
      Rails.logger.info "WorkOrder ##{id}: 更新关联的费用明细状态为 verified"
      update_associated_fee_details_status('verified')
    when "否决", "无法通过"
      Rails.logger.info "WorkOrder ##{id}: 更新关联的费用明细状态为 problematic"
      update_associated_fee_details_status('problematic')
    when nil, ""
      # 处理意见为空，不更新费用明细状态
      Rails.logger.info "WorkOrder ##{id}: 处理意见为空，不更新费用明细状态"
    else
      # 其他任何处理意见，更新费用明细状态为 problematic
      Rails.logger.info "WorkOrder ##{id}: 处理意见为 '#{processing_opinion}'，更新关联的费用明细状态为 problematic"
      update_associated_fee_details_status('problematic')
    end
  rescue => e
    Rails.logger.error "无法基于处理意见更新状态: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
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
    # 通用字段 + 下面添加的特定子类字段
    %w[id reimbursement_id type status created_by created_at updated_at] + subclass_ransackable_attributes
  end
  
  # 子类的占位方法
  def self.subclass_ransackable_attributes
    []
  end
  
  def self.subclass_ransackable_associations
    []
  end
end