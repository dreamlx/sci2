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
    assign_shared_attributes(params) # 分配共享字段
    @audit_work_order.start_processing!
    true
  rescue => e
    @audit_work_order.errors.add(:base, "无法开始处理: #{e.message}")
    false
  end
  
  # 审核通过
  def approve(params = {})
    assign_shared_attributes(params) # 分配共享字段
    @audit_work_order.audit_comment = params[:audit_comment] if params[:audit_comment].present?
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
    if comment.blank?
      @audit_work_order.errors.add(:audit_comment, "必须填写拒绝理由")
      return false
    end
    @audit_work_order.audit_comment = comment
    @audit_work_order.reject!
    true
  rescue => e
    @audit_work_order.errors.add(:base, "无法拒绝: #{e.message}")
    false
  end
  
  # 选择单个费用明细
  def select_fee_detail(fee_detail)
    @audit_work_order.select_fee_detail(fee_detail)
  end
  
  # 选择多个费用明细
  def select_fee_details(fee_detail_ids)
    @audit_work_order.select_fee_details(fee_detail_ids)
  end
  
  # 更新费用明细验证状态
  def update_fee_detail_verification(fee_detail_id, verification_status, comment = nil)
    fee_detail = @audit_work_order.fee_details.find_by(id: fee_detail_id)
    unless fee_detail
      @audit_work_order.errors.add(:base, "未找到关联的费用明细 ##{fee_detail_id}")
      return false
    end
    verification_service = FeeDetailVerificationService.new(@current_admin_user)
    # 使用 bang 方法在失败时引发错误（如果需要）
    verification_service.update_verification_status(fee_detail, verification_status, comment)
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