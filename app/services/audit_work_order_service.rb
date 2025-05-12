# app/services/audit_work_order_service.rb
# frozen_string_literal: true

class AuditWorkOrderService < WorkOrderService
  def initialize(audit_work_order, current_admin_user)
    super(audit_work_order, current_admin_user)
    @audit_work_order = audit_work_order
  end

  def update(params = {})
    # 处理处理意见
    if params[:processing_opinion].present?
      case params[:processing_opinion]
      when "可以通过"
        params[:resolution] = "approved"
      when "无法通过"
        params[:resolution] = "rejected"
        # 验证必填字段
        if params[:problem_type_id].blank?
          @audit_work_order.errors.add(:problem_type_id, "不能为空，当处理意见为无法通过时。")
        end
        if params[:problem_description_id].blank?
          @audit_work_order.errors.add(:problem_description_id, "不能为空，当处理意见为无法通过时。")
        end
        if params[:audit_comment].blank?
          @audit_work_order.errors.add(:audit_comment, "不能为空，当处理意见为无法通过时。")
        end
        return false if @audit_work_order.errors.any?
      end
    end

    super(params)
  end

  private

  def process_work_order
    case @audit_work_order.processing_opinion
    when "可以通过"
      @audit_work_order.update(status: :completed)
    when "无法通过"
      @audit_work_order.update(status: :rejected)
    end
  end
end