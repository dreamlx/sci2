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
  
  # 沟通通过
  def approve(params = {})
    # 支持从pending或processing状态直接到approved的转换
    assign_shared_attributes(params) # 分配共享字段
    
    # 检查是否提供了审核意见
    if params[:audit_comment].blank?
      @communication_work_order.errors.add(:base, "无法批准: 必须填写审核意见")
      return false
    end
    
    @communication_work_order.audit_comment = params[:audit_comment]
    @communication_work_order.approve!
    true
  rescue StandardError => e
    @communication_work_order.errors.add(:base, "无法批准: #{e.message}")
    false
  end
  
  # 沟通拒绝
  def reject(params = {})
    assign_shared_attributes(params) # 分配共享字段
    comment = params[:audit_comment]
    if comment.blank?
      @communication_work_order.errors.add(:base, "无法拒绝: 必须填写拒绝理由")
      return false
    end

    @communication_work_order.audit_comment = comment

    # 确保工单状态为 processing，否则无法拒绝
    if @communication_work_order.status != "processing"
      @communication_work_order.start_processing! if @communication_work_order.status == "pending"
    end

    @communication_work_order.reject!
    true
  rescue StandardError => e
    @communication_work_order.errors.add(:base, "无法拒绝: #{e.message}")
    false
  end
  
  # 更新费用明细验证状态
  def update_fee_detail_verification(fee_detail_id, verification_status, comment = nil)
    fee_detail = FeeDetail.joins(:fee_detail_selections)
                         .where(fee_detail_selections: {
                           work_order_id: @communication_work_order.id,
                           work_order_type: 'CommunicationWorkOrder'
                         })
                         .find_by(id: fee_detail_id)

    unless fee_detail
      @communication_work_order.errors.add(:base, "无法更新费用明细验证状态: 未找到关联的费用明细 ##{fee_detail_id}")
      return false
    end

    begin
      verification_service = FeeDetailVerificationService.new(@current_admin_user)
      result = verification_service.update_verification_status(fee_detail, verification_status, comment)

      # 确保状态更新成功
      fee_detail.reload
      return result
    rescue StandardError => e
      @communication_work_order.errors.add(:base, "无法更新费用明细验证状态: #{e.message}")
      return false
    end
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