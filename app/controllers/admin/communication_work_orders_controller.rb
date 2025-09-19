# app/controllers/admin/communication_work_orders_controller.rb
# frozen_string_literal: true

module Admin
  class CommunicationWorkOrdersController < ActiveAdmin::ResourceController
    before_action :set_communication_work_order, only: [:show, :edit, :update, :destroy]

    def index
      @communication_work_orders = CommunicationWorkOrder.includes(:reimbursement, :creator)
                                                        .order(created_at: :desc)
                                                        .ransack(params[:q])
                                                        .result(distinct: true)
                                                        .page(params[:page])
                                                        .per(20)
      Rails.logger.info "Communication Work Orders: #{@communication_work_orders.inspect}"
      @communication_work_orders.each_with_index do |work_order, index|
        Rails.logger.info "Work Order #{index}: #{work_order.inspect}"
      end
    end

    def show
    end

    def new
      @communication_work_order = CommunicationWorkOrder.new
      if params[:reimbursement_id]
        @communication_work_order.reimbursement_id = params[:reimbursement_id]
      end
    end

    def create
      @communication_work_order = CommunicationWorkOrder.new(communication_work_order_params)
      if @communication_work_order.save
        # 处理费用明细关联
        if params[:communication_work_order][:fee_detail_ids].present?
          @communication_work_order.fee_detail_ids = params[:communication_work_order][:fee_detail_ids]
        end
        redirect_to admin_communication_work_order_path(@communication_work_order), notice: '沟通工单创建成功'
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @communication_work_order.update(communication_work_order_params)
        # 处理费用明细关联
        if params[:communication_work_order][:fee_detail_ids].present?
          @communication_work_order.fee_detail_ids = params[:communication_work_order][:fee_detail_ids]
        end
        redirect_to admin_communication_work_order_path(@communication_work_order), notice: '沟通工单更新成功'
      else
        render :edit
      end
    end

    def destroy
      @communication_work_order.destroy
      redirect_to admin_communication_work_orders_path, notice: '沟通工单删除成功'
    end

    private

    def set_communication_work_order
      @communication_work_order = CommunicationWorkOrder.find(params[:id])
    end

    def communication_work_order_params
      params.require(:communication_work_order).permit(
        :reimbursement_id, :status, :audit_comment,
        :problem_type, :problem_description, :processing_opinion
      )
    end
  end
end 