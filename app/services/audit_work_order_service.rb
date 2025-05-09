# app/services/audit_work_order_service.rb
class AuditWorkOrderService
  def initialize(audit_work_order, current_admin_user)
    raise ArgumentError, "Expected AuditWorkOrder" unless audit_work_order.is_a?(AuditWorkOrder)
    @audit_work_order = audit_work_order
    @current_admin_user = current_admin_user
    Current.admin_user = current_admin_user # 设置 Current 上下文
  end
  
  # 开始处理
  def start_processing(params = {})
    # 注意：处理意见(processing_opinion)与工单状态(status)的关系由模型的
    # set_status_based_on_processing_opinion回调自动处理，无需在服务层显式设置
    assign_shared_attributes(params) # 分配共享字段
    @audit_work_order.start_processing!
    true
  rescue => e
    @audit_work_order.errors.add(:base, "无法开始处理: #{e.message}")
    false
  end
  
  # 审核通过
  def approve(params = {})
    # 支持从pending或processing状态直接到approved的转换
    assign_shared_attributes(params) # 分配共享字段

    # 检查审核意见是否存在
    if params[:audit_comment].blank?
      @audit_work_order.errors.add(:base, "无法批准: 必须填写审核意见")
      return false
    end

    @audit_work_order.audit_comment = params[:audit_comment]
    @audit_work_order.approve!
    true
  rescue => e
    @audit_work_order.errors.add(:base, "无法批准: #{e.message}")
    false
  end
  
  # 审核拒绝
  def reject(params = {})
    assign_shared_attributes(params) # 分配共享字段
    comment = params[:audit_comment]

    # 检查审核意见是否存在
    if comment.blank?
      @audit_work_order.errors.add(:base, "无法拒绝: 必须填写拒绝理由")
      return false
    end

    @audit_work_order.audit_comment = comment

    # 确保工单状态为 processing，否则无法拒绝
    if @audit_work_order.status != "processing"
      @audit_work_order.start_processing! if @audit_work_order.status == "pending"
    end

    @audit_work_order.reject!
    true
  rescue => e
    @audit_work_order.errors.add(:base, "无法拒绝: #{e.message}")
    false
  end
  
  # 更新费用明细验证状态
  def update_fee_detail_verification(fee_detail_id, verification_status, comment = nil)
    fee_detail = FeeDetail.joins(:fee_detail_selections)
                         .where(fee_detail_selections: {
                           work_order_id: @audit_work_order.id,
                           work_order_type: 'AuditWorkOrder'
                         })
                         .find_by(id: fee_detail_id)

    unless fee_detail
      @audit_work_order.errors.add(:base, "无法更新费用明细验证状态: 未找到关联的费用明细 ##{fee_detail_id}")
      return false
    end

    begin
      verification_service = FeeDetailVerificationService.new(@current_admin_user)
      result = verification_service.update_verification_status(fee_detail, verification_status, comment)

      # 确保状态更新成功
      fee_detail.reload
      return result
    rescue StandardError => e
      @audit_work_order.errors.add(:base, "无法更新费用明细验证状态: #{e.message}")
      return false
    end
  end
  
  private
  
  # 处理共享表单属性（来自 Req 6/7）
  def assign_shared_attributes(params)
    # 如果直接从控制器调用，使用 strong parameters
    # permitted_params = params.permit(:problem_type, :problem_description, :remark, :processing_opinion)
    # 对于内部服务调用，使用 slice 即可
    shared_attrs = params.slice(:problem_type, :problem_description, :remark, :processing_opinion)
    @audit_work_order.assign_attributes(shared_attrs) if shared_attrs.present?
  end
end