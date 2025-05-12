module Admin
  class AuditWorkOrdersController < Admin::BaseController
    before_action :set_audit_work_order, only: [:show, :edit, :update, :destroy, :verify_fee_detail, :do_verify_fee_detail]

    def index
      @audit_work_orders = AuditWorkOrder.includes(:reimbursement, :creator)
                                        .order(created_at: :desc)
                                        .ransack(params[:q])
                                        .result(distinct: true)
                                        .page(params[:page])
                                        .per(20)
    end

    def show
    end

    def new
      @audit_work_order = AuditWorkOrder.new
      if params[:reimbursement_id]
        @audit_work_order.reimbursement_id = params[:reimbursement_id]
      end
    end

    def create
      @audit_work_order = AuditWorkOrder.new(audit_work_order_params)
      if @audit_work_order.save
        # 处理费用明细关联
        if params[:audit_work_order][:fee_detail_ids].present?
          @audit_work_order.fee_detail_ids = params[:audit_work_order][:fee_detail_ids]
        end
        redirect_to admin_audit_work_order_path(@audit_work_order), notice: '审核工单创建成功'
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @audit_work_order.update(audit_work_order_params)
        # 处理费用明细关联
        if params[:audit_work_order][:fee_detail_ids].present?
          @audit_work_order.fee_detail_ids = params[:audit_work_order][:fee_detail_ids]
        end
        redirect_to admin_audit_work_order_path(@audit_work_order), notice: '审核工单更新成功'
      else
        render :edit
      end
    end

    def destroy
      @audit_work_order.destroy
      redirect_to admin_audit_work_orders_path, notice: '审核工单删除成功'
    end

    def verify_fee_detail
      @fee_detail = FeeDetail.find(params[:fee_detail_id])
      @selection = @audit_work_order.fee_detail_selections.find_by(fee_detail_id: @fee_detail.id)
    end

    def do_verify_fee_detail
      @fee_detail = FeeDetail.find(params[:fee_detail_id])
      @selection = @audit_work_order.fee_detail_selections.find_by(fee_detail_id: @fee_detail.id)

      if @fee_detail.update(verification_status: params[:verification_status])
        @selection.update(verification_comment: params[:comment])
        redirect_to admin_audit_work_order_path(@audit_work_order), notice: '费用明细验证状态更新成功'
      else
        render :verify_fee_detail
      end
    end

    private

    def set_audit_work_order
      @audit_work_order = AuditWorkOrder.find(params[:id])
    end

    def audit_work_order_params
      params.require(:audit_work_order).permit(
        :reimbursement_id, :status, :audit_result, :audit_comment,
        :problem_type, :problem_description, :remark, :processing_opinion
      )
    end
  end
end 