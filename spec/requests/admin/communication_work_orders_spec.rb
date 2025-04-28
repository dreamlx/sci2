require 'rails_helper'

RSpec.describe "Admin::CommunicationWorkOrders", type: :request do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  let!(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement, status: 'pending') }

  before do
    sign_in admin_user
  end

  describe "GET /admin/communication_work_orders" do
    it "返回成功响应" do
      get admin_communication_work_orders_path
      expect(response).to be_successful
    end
  end

  describe "GET /admin/communication_work_orders/:id" do
    it "返回成功响应" do
      get admin_communication_work_order_path(communication_work_order)
      expect(response).to be_successful
    end
  end

  describe "POST /admin/communication_work_orders" do
    let(:valid_params) do
      {
        communication_work_order: {
          reimbursement_id: reimbursement.id,
          problem_type: "发票问题",
          problem_description: "发票信息不完整",
          remark: "测试备注",
          processing_opinion: "需要补充材料",
          fee_detail_ids: [fee_detail.id]
        }
      }
    end

    it "creates a new CommunicationWorkOrder" do
      expect do
        post admin_communication_work_orders_path, params: valid_params
      end.to change(CommunicationWorkOrder, :count).by(1)
      expect(response).to redirect_to(admin_communication_work_order_path(CommunicationWorkOrder.last))
      follow_redirect!
      expect(response.body).to include("沟通工单创建成功")
    end

    it "calls the CommunicationWorkOrderService with correct parameters" do
      service_double = instance_double(CommunicationWorkOrderService::Creator)
      allow(CommunicationWorkOrderService::Creator).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:call).and_return(double(success?: true, work_order: build_stubbed(:communication_work_order)))

      post admin_communication_work_orders_path, params: valid_params

      expect(CommunicationWorkOrderService::Creator).to have_received(:new).with(valid_params[:communication_work_order])
      expect(service_double).to have_received(:call)
    end
  end

  describe "PUT /admin/communication_work_orders/:id" do
    let(:new_attributes) do
      {
        problem_type: "金额错误",
        remark: "更新测试备注"
      }
    end

    it "updates the requested communication_work_order" do
      put admin_communication_work_order_path(communication_work_order), params: { communication_work_order: new_attributes }
      communication_work_order.reload
      expect(communication_work_order.problem_type).to eq("金额错误")
      expect(communication_work_order.remark).to eq("更新测试备注")
      expect(response).to redirect_to(admin_communication_work_order_path(communication_work_order))
      follow_redirect!
      expect(response.body).to include("沟通工单更新成功")
    end

    it "calls the CommunicationWorkOrderService with correct parameters" do
      service_double = instance_double(CommunicationWorkOrderService::Updater)
      allow(CommunicationWorkOrderService::Updater).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:call).and_return(double(success?: true, work_order: communication_work_order))

      put admin_communication_work_order_path(communication_work_order), params: { communication_work_order: new_attributes }

      expect(CommunicationWorkOrderService::Updater).to have_received(:new).with(communication_work_order, new_attributes)
      expect(service_double).to have_received(:call)
    end
  end

  describe "PUT /admin/communication_work_orders/:id/approve" do
    it "approves the communication work order" do
      service_double = instance_double(CommunicationWorkOrderService::Approver)
      allow(CommunicationWorkOrderService::Approver).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:call).and_return(double(success?: true, work_order: communication_work_order))

      put approve_admin_communication_work_order_path(communication_work_order)

      expect(CommunicationWorkOrderService::Approver).to have_received(:new).with(communication_work_order)
      expect(service_double).to have_received(:call)
      expect(response).to redirect_to(admin_communication_work_order_path(communication_work_order))
      follow_redirect!
      expect(response.body).to include("沟通工单已通过")
    end
  end

  describe "PUT /admin/communication_work_orders/:id/reject" do
    it "rejects the communication work order" do
      service_double = instance_double(CommunicationWorkOrderService::Rejecter)
      allow(CommunicationWorkOrderService::Rejecter).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:call).and_return(double(success?: true, work_order: communication_work_order))

      put reject_admin_communication_work_order_path(communication_work_order)

      expect(CommunicationWorkOrderService::Rejecter).to have_received(:new).with(communication_work_order)
      expect(service_double).to have_received(:call)
      expect(response).to redirect_to(admin_communication_work_order_path(communication_work_order))
      follow_redirect!
      expect(response.body).to include("沟通工单已拒绝")
    end
  end

  describe "PUT /admin/communication_work_orders/:id/verify_fee_detail" do
    let(:fee_detail_to_verify) { create(:fee_detail, document_number: reimbursement.invoice_number, verification_status: 'problematic') }
    let!(:communication_work_order_with_fee_detail) { create(:communication_work_order, reimbursement: reimbursement, fee_details: [fee_detail_to_verify], status: 'processing') }

    it "verifies the associated fee detail" do
      service_double = instance_double(FeeDetailVerificationService)
      allow(FeeDetailVerificationService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:call).and_return(double(success?: true, fee_detail: fee_detail_to_verify))

      put verify_fee_detail_admin_communication_work_order_path(communication_work_order_with_fee_detail), params: { fee_detail_id: fee_detail_to_verify.id }

      expect(FeeDetailVerificationService).to have_received(:new).with(fee_detail_to_verify)
      expect(service_double).to have_received(:call)
      expect(response).to redirect_to(admin_communication_work_order_path(communication_work_order_with_fee_detail))
      follow_redirect!
      expect(response.body).to include("费用明细验证状态更新成功")
    end
  end
end