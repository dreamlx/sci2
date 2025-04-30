require 'rails_helper'

RSpec.describe "Admin::CustomViews", type: :request do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'processing') }
  let!(:communication_work_order) { create(:communication_work_order, :needs_communication, reimbursement: reimbursement, status: 'processing') }
  let!(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  let!(:fee_detail_selection) { create(:fee_detail_selection, work_order: audit_work_order, fee_detail: fee_detail) }

  before do
    sign_in admin_user
  end

  describe "审核工单状态流转表单" do
    it "GET /admin/audit_work_orders/:id/approve 返回成功响应" do
      get approve_admin_audit_work_order_path(audit_work_order)
      expect(response).to be_successful
    end

    it "GET /admin/audit_work_orders/:id/reject 返回成功响应" do
      get reject_admin_audit_work_order_path(audit_work_order)
      expect(response).to be_successful
    end

    it "POST /admin/audit_work_orders/:id/do_approve 处理审核通过请求" do
      service_double = instance_double(AuditWorkOrderService)
      allow(AuditWorkOrderService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:approve).and_return(double(success?: true, work_order: audit_work_order))

      post do_approve_admin_audit_work_order_path(audit_work_order), params: {
        audit_work_order: {
          audit_comment: "测试审核通过",
          audit_date: Date.today,
          vat_verified: true
        }
      }

      expect(AuditWorkOrderService).to have_received(:new).with(audit_work_order, admin_user)
      expect(service_double).to have_received(:approve).with(hash_including(audit_comment: "测试审核通过", vat_verified: true))
      expect(response).to redirect_to(admin_audit_work_order_path(audit_work_order))
    end

    it "POST /admin/audit_work_orders/:id/do_reject 处理审核拒绝请求" do
      service_double = instance_double(AuditWorkOrderService)
      allow(AuditWorkOrderService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:reject).and_return(double(success?: true, work_order: audit_work_order))

      post do_reject_admin_audit_work_order_path(audit_work_order), params: {
        audit_work_order: {
          audit_comment: "测试审核拒绝",
          audit_date: Date.today
        }
      }

      expect(AuditWorkOrderService).to have_received(:new).with(audit_work_order, admin_user)
      expect(service_double).to have_received(:reject).with(hash_including(audit_comment: "测试审核拒绝"))
      expect(response).to redirect_to(admin_audit_work_order_path(audit_work_order))
    end
  end

  describe "沟通工单状态流转表单" do
    it "GET /admin/communication_work_orders/:id/approve 返回成功响应" do
      get approve_admin_communication_work_order_path(communication_work_order)
      expect(response).to be_successful
    end

    it "GET /admin/communication_work_orders/:id/reject 返回成功响应" do
      get reject_admin_communication_work_order_path(communication_work_order)
      expect(response).to be_successful
    end

    it "POST /admin/communication_work_orders/:id/do_approve 处理沟通通过请求" do
      service_double = instance_double(CommunicationWorkOrderService)
      allow(CommunicationWorkOrderService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:approve).and_return(double(success?: true, work_order: communication_work_order))

      post do_approve_admin_communication_work_order_path(communication_work_order), params: {
        communication_work_order: {
          resolution_summary: "测试沟通通过"
        }
      }

      expect(CommunicationWorkOrderService).to have_received(:new).with(communication_work_order, admin_user)
      expect(service_double).to have_received(:approve).with(hash_including(resolution_summary: "测试沟通通过"))
      expect(response).to redirect_to(admin_communication_work_order_path(communication_work_order))
    end

    it "POST /admin/communication_work_orders/:id/do_reject 处理沟通拒绝请求" do
      service_double = instance_double(CommunicationWorkOrderService)
      allow(CommunicationWorkOrderService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:reject).and_return(double(success?: true, work_order: communication_work_order))

      post do_reject_admin_communication_work_order_path(communication_work_order), params: {
        communication_work_order: {
          resolution_summary: "测试沟通拒绝"
        }
      }

      expect(CommunicationWorkOrderService).to have_received(:new).with(communication_work_order, admin_user)
      expect(service_double).to have_received(:reject).with(hash_including(resolution_summary: "测试沟通拒绝"))
      expect(response).to redirect_to(admin_communication_work_order_path(communication_work_order))
    end
  end

  describe "费用明细验证表单" do
    it "GET /admin/audit_work_orders/:id/verify_fee_detail 返回成功响应" do
      get verify_fee_detail_admin_audit_work_order_path(audit_work_order, fee_detail_id: fee_detail.id)
      expect(response).to be_successful
    end

    it "POST /admin/audit_work_orders/:id/do_verify_fee_detail 处理验证状态更新请求" do
      service_double = instance_double(FeeDetailVerificationService)
      allow(FeeDetailVerificationService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:update_verification_status).and_return(true) # Assuming the service returns boolean

      post do_verify_fee_detail_admin_audit_work_order_path(audit_work_order), params: {
        fee_detail_id: fee_detail.id,
        verification_status: "verified",
        comment: "测试验证通过"
      }

      expect(FeeDetailVerificationService).to have_received(:new).with(admin_user)
      expect(service_double).to have_received(:update_verification_status).with(fee_detail, "verified", "测试验证通过")
      expect(response).to redirect_to(admin_audit_work_order_path(audit_work_order))
    end
  end

  describe "沟通记录添加表单" do
    it "GET /admin/communication_work_orders/:id/new_communication_record 返回成功响应" do
      get new_communication_record_admin_communication_work_order_path(communication_work_order)
      expect(response).to be_successful
    end

    it "POST /admin/communication_work_orders/:id/create_communication_record 处理添加沟通记录请求" do
      service_double = instance_double(CommunicationWorkOrderService)
      allow(CommunicationWorkOrderService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:add_communication_record).and_return(build_stubbed(:communication_record, persisted?: true)) # Assuming the service returns the record

      post create_communication_record_admin_communication_work_order_path(communication_work_order), params: {
        communication_record: {
          content: "测试沟通内容",
          communicator_role: "财务人员",
          communicator_name: "张三",
          communication_method: "电话"
        }
      }

      expect(CommunicationWorkOrderService).to have_received(:new).with(communication_work_order, admin_user)
      expect(service_double).to have_received(:add_communication_record).with(hash_including(content: "测试沟通内容", communicator_role: "财务人员", communicator_name: "张三", communication_method: "电话"))
      expect(response).to redirect_to(admin_communication_work_order_path(communication_work_order))
    end
  end
end