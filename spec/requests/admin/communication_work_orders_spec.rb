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
  end

  describe "PUT /admin/communication_work_orders/:id/approve" do
    it "approves the communication work order" do
      service_double = instance_double(CommunicationWorkOrderService)
      allow(CommunicationWorkOrderService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:approve).and_return(double(success?: true, work_order: communication_work_order))

      put approve_admin_communication_work_order_path(communication_work_order)

      expect(CommunicationWorkOrderService).to have_received(:new).with(communication_work_order, admin_user)
      expect(service_double).to have_received(:approve)
      expect(response).to redirect_to(admin_communication_work_order_path(communication_work_order))
      follow_redirect!
      expect(response.body).to include("沟通工单已通过")
    end
  end

  describe "PUT /admin/communication_work_orders/:id/reject" do
    it "rejects the communication work order" do
      service_double = instance_double(CommunicationWorkOrderService)
      allow(CommunicationWorkOrderService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:reject).and_return(double(success?: true, work_order: communication_work_order))

      put reject_admin_communication_work_order_path(communication_work_order), params: { communication_work_order: { resolution_summary: "测试拒绝理由" } }

      expect(CommunicationWorkOrderService).to have_received(:new).with(communication_work_order, admin_user)
      expect(service_double).to have_received(:reject).with(hash_including(resolution_summary: "测试拒绝理由"))
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
      allow(service_double).to receive(:update_verification_status).and_return(true) # Assuming the service returns boolean

      put verify_fee_detail_admin_communication_work_order_path(communication_work_order_with_fee_detail), params: { fee_detail_id: fee_detail_to_verify.id, verification_status: 'verified' }

      expect(FeeDetailVerificationService).to have_received(:new).with(admin_user)
      expect(service_double).to have_received(:update_verification_status).with(fee_detail_to_verify.id, 'verified', nil)
      expect(response).to redirect_to(admin_communication_work_order_path(communication_work_order_with_fee_detail))
      follow_redirect!
      expect(response.body).to include("费用明细验证状态更新成功")
    end
  end
end