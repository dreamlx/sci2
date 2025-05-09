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
    # 通过 CommunicationWorkOrder 的 fee_details 关联来查找特定的 FeeDetail
    fee_detail = @communication_work_order.fee_details.find_by(id: fee_detail_id)

    unless fee_detail
      error_message = "无法更新费用明细验证状态: 费用明细 ##{fee_detail_id} 未找到或未与此工单关联。"
      @communication_work_order.errors.add(:base, error_message)
      Rails.logger.warn "[CommunicationWorkOrderService] #{error_message} WorkOrder ID: #{@communication_work_order.id}"
      return false
    end

    begin
      verification_service = FeeDetailVerificationService.new(@current_admin_user)
      result = verification_service.update_verification_status(fee_detail, verification_status, comment)

      unless result
         fee_detail.errors.full_messages.each do |msg|
            @communication_work_order.errors.add(:base, "费用明细 ##{fee_detail.id} 更新失败: #{msg}")
         end
         Rails.logger.warn "[CommunicationWorkOrderService] FeeDetailVerificationService failed for FeeDetail ##{fee_detail.id} on WorkOrder ID: #{@communication_work_order.id}. Errors: #{fee_detail.errors.full_messages.join(', ')}"
      end
      
      return result
    rescue StandardError => e
      error_message = "更新费用明细 ##{fee_detail_id} 验证状态时发生内部错误: #{e.message}"
      @communication_work_order.errors.add(:base, error_message)
      Rails.logger.error "[CommunicationWorkOrderService] #{error_message} WorkOrder ID: #{@communication_work_order.id}. Backtrace: #{e.backtrace.join("\n")}"
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