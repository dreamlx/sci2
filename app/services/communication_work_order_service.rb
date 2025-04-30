# app/services/communication_work_order_service.rb
class CommunicationWorkOrderService
  def initialize(communication_work_order, current_admin_user)
    raise ArgumentError, "Expected CommunicationWorkOrder" unless communication_work_order.is_a?(CommunicationWorkOrder)
    @communication_work_order = communication_work_order
    @current_admin_user = current_admin_user
    Current.admin_user = current_admin_user # 设置 Current 上下文
  end
  
  # 开始处理
  def start_processing(params = {})
    # 注意：处理意见(processing_opinion)与工单状态(status)的关系由模型的
    # set_status_based_on_processing_opinion回调自动处理，无需在服务层显式设置
    assign_shared_attributes(params) # 分配共享字段
    @communication_work_order.start_processing!
    true
  rescue StandardError => e
    @communication_work_order.errors.add(:base, "无法开始处理: #{e.message}")
    false
  end
  
  # 切换需要沟通标志（布尔字段，非状态值）
  def toggle_needs_communication(value = nil)
    value = !@communication_work_order.needs_communication if value.nil?
    if @communication_work_order.update(needs_communication: value)
      true
    else
      @communication_work_order.errors.add(:base, "无法更新沟通标志")
      false
    end
  end
  
  # 沟通通过
  def approve(params = {})
    # 支持从pending或processing状态直接到approved的转换
    assign_shared_attributes(params) # 分配共享字段
    @communication_work_order.resolution_summary = params[:resolution_summary] if params[:resolution_summary].present?
    @communication_work_order.approve!
    true
  rescue StandardError => e
    @communication_work_order.errors.add(:base, "无法批准: #{e.message}")
    false
  end
  
  # 沟通拒绝
  def reject(params = {})
    assign_shared_attributes(params) # 分配共享字段
    summary = params[:resolution_summary]
    if summary.blank?
      @communication_work_order.errors.add(:resolution_summary, "必须填写拒绝理由/摘要")
      return false
    end
    @communication_work_order.resolution_summary = summary
    @communication_work_order.reject!
    true
  rescue StandardError => e
    @communication_work_order.errors.add(:base, "无法拒绝: #{e.message}")
    false
  end
  
  # 添加沟通记录
  def add_communication_record(params)
    record = @communication_work_order.add_communication_record(
      params.slice(:content, :communicator_role, :communicator_name, :communication_method).merge(
        communicator_name: params[:communicator_name] || @current_admin_user.email,
        recorded_at: Time.current
      )
    )
    unless record.persisted?
      @communication_work_order.errors.add(:base, "添加沟通记录失败: #{record.errors.full_messages.join(', ')}")
    end
    record
  end
  
  # 选择单个费用明细
  def select_fee_detail(fee_detail)
    @communication_work_order.select_fee_detail(fee_detail)
  end
  
  # 选择多个费用明细
  def select_fee_details(fee_detail_ids)
    @communication_work_order.select_fee_details(fee_detail_ids)
  end
  
  # 更新费用明细验证状态
  def update_fee_detail_verification(fee_detail_id, verification_status, comment = nil)
    fee_detail = @communication_work_order.fee_details.find_by(id: fee_detail_id)
    unless fee_detail
      @communication_work_order.errors.add(:base, "未找到关联的费用明细 ##{fee_detail_id}")
      return false
    end
    verification_service = FeeDetailVerificationService.new(@current_admin_user)
    verification_service.update_verification_status(fee_detail, verification_status, comment)
  end
  
  private
  
  # 处理共享表单属性（来自 Req 6/7）
  def assign_shared_attributes(params)
    # 如果直接从控制器调用，使用 strong parameters
    # permitted_params = params.permit(:problem_type, :problem_description, :remark, :processing_opinion)
    shared_attrs = params.slice(:problem_type, :problem_description, :remark, :processing_opinion)
    @communication_work_order.assign_attributes(shared_attrs) if shared_attrs.present?
  end
end