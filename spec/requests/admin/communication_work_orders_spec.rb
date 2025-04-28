require 'rails_helper'

RSpec.describe "Admin::CommunicationWorkOrders", type: :request do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement) }
  let!(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  let!(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement, audit_work_order: audit_work_order, status: 'pending') }

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

  describe "PUT /admin/communication_work_orders/:id/start_processing" do
    it "更新工单状态" do
      put start_processing_admin_communication_work_order_path(communication_work_order)
      expect(response).to redirect_to(admin_communication_work_order_path(communication_work_order))
      follow_redirect!
      expect(response.body).to include("工单已开始处理")
    end
  end

  describe "PUT /admin/communication_work_orders/:id/mark_needs_communication" do
    it "更新工单状态" do
      put mark_needs_communication_admin_communication_work_order_path(communication_work_order)
      expect(response).to redirect_to(admin_communication_work_order_path(communication_work_order))
      follow_redirect!
      expect(response.body).to include("工单已标记为需要沟通")
    end
  end

  describe "GET /admin/communication_work_orders/:id/new_communication_record" do
    it "返回成功响应" do
      get new_communication_record_admin_communication_work_order_path(communication_work_order)
      expect(response).to be_successful
    end
  end

  describe "POST /admin/communication_work_orders/:id/create_communication_record" do
    it "创建沟通记录" do
      post create_communication_record_admin_communication_work_order_path(communication_work_order), params: {
        communication_record: {
          content: "测试沟通内容",
          communicator_role: "财务人员",
          communicator_name: "张三",
          communication_method: "电话"
        }
      }
      expect(response).to redirect_to(admin_communication_work_order_path(communication_work_order))
      follow_redirect!
      expect(response.body).to include("沟通记录已添加")
    end
  end
end