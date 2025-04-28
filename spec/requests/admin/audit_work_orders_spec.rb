require 'rails_helper'

RSpec.describe "Admin::AuditWorkOrders", type: :request do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  let!(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'pending') }

  before do
    sign_in admin_user
  end

  describe "GET /admin/audit_work_orders" do
    it "返回成功响应" do
      get admin_audit_work_orders_path
      expect(response).to be_successful
    end
  end

  describe "GET /admin/audit_work_orders/:id" do
    it "返回成功响应" do
      get admin_audit_work_order_path(audit_work_order)
      expect(response).to be_successful
    end
  end

  describe "PUT /admin/audit_work_orders/:id/start_processing" do
    it "更新工单状态" do
      put start_processing_admin_audit_work_order_path(audit_work_order)
      expect(response).to redirect_to(admin_audit_work_order_path(audit_work_order))
      follow_redirect!
      expect(response.body).to include("工单已开始处理")
    end
  end

  describe "GET /admin/audit_work_orders/:id/approve" do
    it "返回成功响应" do
      # 先将工单状态设为processing
      audit_work_order.update(status: 'processing')

      get approve_admin_audit_work_order_path(audit_work_order)
      expect(response).to be_successful
    end
  end

  describe "POST /admin/audit_work_orders/:id/do_approve" do
    it "审核通过工单" do
      # 先将工单状态设为processing
      audit_work_order.update(status: 'processing')

      post do_approve_admin_audit_work_order_path(audit_work_order), params: {
        audit_work_order: { audit_comment: "审核通过测试" }
      }
      expect(response).to redirect_to(admin_audit_work_order_path(audit_work_order))
      follow_redirect!
      expect(response.body).to include("审核已通过")
    end
  end
end