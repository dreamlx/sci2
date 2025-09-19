# app/models/work_order.rb
class WorkOrder < ApplicationRecord
  # 使用STI实现不同类型的工单
  self.inheritance_column = :type
  
  # 常量
  STATUS_PENDING = 'pending'.freeze
  STATUS_APPROVED = 'approved'.freeze
  STATUS_REJECTED = 'rejected'.freeze
  STATUS_COMPLETED = 'completed'.freeze
  
  # 关联
  belongs_to :reimbursement
  belongs_to :problem_type, optional: true # 保留向后兼容
  belongs_to :creator, class_name: 'AdminUser', foreign_key: 'created_by', optional: true
  
  # 新增多对多关联
  has_many :work_order_problems, dependent: :destroy
  has_many :problem_types, through: :work_order_problems
  
  # 修改关联定义，使用普通的has_many而不是多态关联
  has_many :work_order_fee_details, dependent: :destroy
  has_many :fee_details, through: :work_order_fee_details
  
  has_many :operations, class_name: 'WorkOrderOperation', dependent: :destroy
  has_many :work_order_status_changes, as: :work_order, dependent: :destroy
  
  # 验证
  validates :reimbursement_id, presence: true
  validates :status, presence: true
  
  # 回调：创建工单后更新报销单通知状态
  after_create :update_reimbursement_notification_status
  after_update :update_reimbursement_notification_status
  after_destroy :update_reimbursement_notification_status
  
  # 虚拟属性，用于表单处理
  attr_accessor :submitted_fee_detail_ids, :problem_type_ids
  
  # 状态机
  state_machine :status, initial: :pending do
    # 定义状态
    state :pending, value: 'pending'
    state :processing, value: 'processing'
    state :approved, value: 'approved'
    state :rejected, value: 'rejected'
    state :completed, value: 'completed'
    
    # 定义事件
    event :start_processing do
      transition pending: :processing
    end
    
    event :approve do
      transition [:pending, :processing] => :approved
    end
    
    event :reject do
      transition [:pending, :processing] => :rejected
    end
    
    # complete 事件只适用于快递工单，审核工单和沟通工单不使用此事件
    event :complete do
      transition [:approved, :rejected] => :completed, if: -> { is_a?(ExpressReceiptWorkOrder) }
    end
    
    # 状态变更回调
    after_transition any => any do |work_order, transition|
      # 记录状态变更
      WorkOrderOperation.create!(
        work_order: work_order,
        operation_type: WorkOrderOperation::OPERATION_TYPE_STATUS_CHANGE,
        details: "状态变更: #{transition.from} -> #{transition.to}",
        admin_user_id: Current.admin_user&.id
      ) if defined?(WorkOrderOperation)
      
      # 更新费用明细状态
      work_order.sync_fee_details_verification_status
    end
  end
  # Ransack 搜索支持
  def self.ransackable_attributes(auth_object = nil)
    ["audit_comment", "audit_date", "audit_result", "communication_method", "courier_name",
     "created_at", "created_by", "fee_type_id", "id", "id_value", "initiator_role",
     "problem_type_id", "processing_opinion", "received_at", "reimbursement_id",
     "status", "tracking_number", "type", "updated_at", "vat_verified", "filling_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["creator", "fee_details", "operations", "problem_type", "problem_types", 
     "reimbursement", "work_order_fee_details", "work_order_problems", 
     "work_order_status_changes"]
  end
  
  # 范围
  scope :pending, -> { where(status: STATUS_PENDING) }
  scope :approved, -> { where(status: STATUS_APPROVED) }
  scope :rejected, -> { where(status: STATUS_REJECTED) }
  scope :completed, -> { where(status: STATUS_COMPLETED) }
  scope :by_reimbursement, ->(reimbursement_id) { where(reimbursement_id: reimbursement_id) }
  scope :recent_first, -> { order(created_at: :desc) }
  
  # 回调
  after_create :log_creation
  after_create :update_reimbursement_status_on_create
  after_create :update_reimbursement_notification_status, if: :express_receipt_work_order?
  after_update :log_update
  after_update :update_reimbursement_notification_status, if: :express_receipt_work_order?
  after_save :process_submitted_fee_details, if: -> { @_direct_submitted_fee_ids.present? }
  after_save :process_problem_types, if: -> { @problem_type_ids.present? }
  after_save :set_status_based_on_processing_opinion, if: -> { processing_opinion.present? && persisted? }
  
  # 方法
  
  # 判断工单是否可编辑
  def editable?
    pending?
  end
  
  # 同步费用明细验证状态 - 简化版本
  def sync_fee_details_verification_status
    # 添加调试日志
    Rails.logger.debug "WorkOrder#sync_fee_details_verification_status: 开始同步费用明细状态，工单 ##{id}, 当前状态: #{status}"
    
    # 直接使用关联获取费用明细ID
    fee_detail_ids = fee_details.pluck(:id)
    Rails.logger.debug "WorkOrder#sync_fee_details_verification_status: 关联的费用明细ID: #{fee_detail_ids.inspect}"
    
    # 使用服务更新费用明细状态
    if fee_detail_ids.any?
      Rails.logger.debug "WorkOrder#sync_fee_details_verification_status: 调用 FeeDetailStatusService.update_status"
      FeeDetailStatusService.new(fee_detail_ids).update_status
      Rails.logger.debug "WorkOrder#sync_fee_details_verification_status: 费用明细状态更新完成"
    else
      Rails.logger.debug "WorkOrder#sync_fee_details_verification_status: 没有关联的费用明细，跳过更新"
    end
  end
  
  # 处理提交的费用明细ID
  def process_submitted_fee_details
    # 获取提交的费用明细ID
    submitted_ids = Array(@_direct_submitted_fee_ids).map(&:to_i).uniq
    
    # 清除实例变量
    @_direct_submitted_fee_ids = nil
    
    # 获取当前关联的费用明细ID
    current_ids = work_order_fee_details.pluck(:fee_detail_id)
    
    # 计算需要添加和删除的ID
    ids_to_add = submitted_ids - current_ids
    ids_to_remove = current_ids - submitted_ids
    
    # 添加新关联
    ids_to_add.each do |fee_detail_id|
      work_order_fee_details.create(fee_detail_id: fee_detail_id)
    end
    
    # 删除旧关联
    if ids_to_remove.any?
      work_order_fee_details.where(fee_detail_id: ids_to_remove).destroy_all
    end
    
    # 更新费用明细状态
    sync_fee_details_verification_status
  end
  
  # 处理问题类型ID
  def process_problem_types
    # 获取提交的问题类型ID
    problem_ids = Array(@problem_type_ids).map(&:to_i).uniq
    
    # 清除实例变量
    @problem_type_ids = nil
    
    # 使用服务处理问题类型
    WorkOrderProblemService.new(self).add_problems(problem_ids)
  end
  
  # 根据处理意见设置状态
  def set_status_based_on_processing_opinion
    return unless respond_to?(:processing_opinion)
    
    case processing_opinion
    when '可以通过'
      # 直接尝试调用 approve 方法，并处理可能的异常
      begin
        approve
        # 记录日志
        Rails.logger.info "WorkOrder ##{id}: 状态已更新为 approved"
      rescue StateMachines::InvalidTransition => e
        # 记录警告日志
        Rails.logger.warn "WorkOrder ##{id}: 无法更新为 approved，当前状态: #{status}, 错误: #{e.message}"
      end
    when '无法通过'
      # 直接尝试调用 reject 方法，并处理可能的异常
      begin
        reject
        # 记录日志
        Rails.logger.info "WorkOrder ##{id}: 状态已更新为 rejected"
      rescue StateMachines::InvalidTransition => e
        # 记录警告日志
        Rails.logger.warn "WorkOrder ##{id}: 无法更新为 rejected，当前状态: #{status}, 错误: #{e.message}"
      end
    end
  end
  
  private
  
  # 记录创建操作
  def log_creation
    # 优先使用当前用户，如果没有则使用工单的创建者，最后使用默认值
    admin_user_id = Current.admin_user&.id || created_by || 1
    
    WorkOrderOperation.create!(
      work_order: self,
      operation_type: WorkOrderOperation::OPERATION_TYPE_CREATE,
      details: "创建#{self.class.name.underscore.humanize}",
      admin_user_id: admin_user_id
    ) if defined?(WorkOrderOperation)
  end
  
  # 记录更新操作
  def log_update
    # 只记录重要字段的变更
    important_changes = saved_changes.except('updated_at', 'created_at')
    
    if important_changes.any?
      change_details = important_changes.map do |attr, values|
        "#{attr}: #{values[0].inspect} -> #{values[1].inspect}"
      end.join(', ')
      
      WorkOrderOperation.create!(
        work_order: self,
        operation_type: WorkOrderOperation::OPERATION_TYPE_UPDATE,
        details: "更新: #{change_details}",
        admin_user_id: Current.admin_user&.id
      ) if defined?(WorkOrderOperation)
    end
  end
  
  # 根据工单类型更新报销单状态
  def update_reimbursement_status_on_create
    # 只为审核工单和沟通工单更新状态
    if is_a?(AuditWorkOrder) || is_a?(CommunicationWorkOrder)
      # 只有当报销单处于pending状态时才更新
      if reimbursement.pending?
        # 添加调试日志
        Rails.logger.debug "WorkOrder#update_reimbursement_status_on_create: 更新报销单 ##{reimbursement.id} 状态，从 #{reimbursement.status} 到 processing"
        
        # 触发状态机事件，将状态更改为processing
        reimbursement.start_processing
        
        Rails.logger.debug "WorkOrder#update_reimbursement_status_on_create: 报销单状态更新后: #{reimbursement.status}"
      else
        Rails.logger.debug "WorkOrder#update_reimbursement_status_on_create: 报销单 ##{reimbursement.id} 不是 pending 状态，当前状态: #{reimbursement.status}"
      end
    else
      Rails.logger.debug "WorkOrder#update_reimbursement_status_on_create: 工单类型 #{self.class.name} 不需要更新报销单状态"
    end
  end
  
  def express_receipt_work_order?
    type == 'ExpressReceiptWorkOrder'
  end
  
  def update_reimbursement_notification_status
    return unless reimbursement
    
    reimbursement.update_notification_status!
  end
end