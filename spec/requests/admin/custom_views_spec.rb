require 'rails_helper'

RSpec.describe "Admin::CustomViews", type: :request do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'processing') }
  let!(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement, status: 'needs_communication') }
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
      service_double = instance_double(AuditWorkOrderService::Approver)
      allow(AuditWorkOrderService::Approver).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:call).and_return(double(success?: true, work_order: audit_work_order))

      post do_approve_admin_audit_work_order_path(audit_work_order), params: {
        audit_work_order: {
          audit_comment: "测试审核通过",
          audit_date: Date.today,
          vat_verified: true
        }
      }

      expect(AuditWorkOrderService::Approver).to have_received(:new).with(audit_work_order, hash_including(audit_comment: "测试审核通过", vat_verified: true))
      expect(service_double).to have_received(:call)
      expect(response).to redirect_to(admin_audit_work_order_path(audit_work_order))
    end

    it "POST /admin/audit_work_orders/:id/do_reject 处理审核拒绝请求" do
      service_double = instance_double(AuditWorkOrderService::Rejecter)
      allow(AuditWorkOrderService::Rejecter).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:call).and_return(double(success?: true, work_order: audit_work_order))

      post do_reject_admin_audit_work_order_path(audit_work_order), params: {
        audit_work_order: {
          audit_comment: "测试审核拒绝",
          audit_date: Date.today
        }
      }

      expect(AuditWorkOrderService::Rejecter).to have_received(:new).with(audit_work_order, hash_including(audit_comment: "测试审核拒绝"))
      expect(service_double).to have_received(:call)
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
      service_double = instance_double(CommunicationWorkOrderService::Approver)
      allow(CommunicationWorkOrderService::Approver).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:call).and_return(double(success?: true, work_order: communication_work_order))

      post do_approve_admin_communication_work_order_path(communication_work_order), params: {
        communication_work_order: {
          resolution_summary: "测试沟通通过"
        }
      }

      expect(CommunicationWorkOrderService::Approver).to have_received(:new).with(communication_work_order, hash_including(resolution_summary: "测试沟通通过"))
      expect(service_double).to have_received(:call)
      expect(response).to redirect_to(admin_communication_work_order_path(communication_work_order))
    end

    it "POST /admin/communication_work_orders/:id/do_reject 处理沟通拒绝请求" do
      service_double = instance_double(CommunicationWorkOrderService::Rejecter)
      allow(CommunicationWorkOrderService::Rejecter).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:call).and_return(double(success?: true, work_order: communication_work_order))

      post do_reject_admin_communication_work_order_path(communication_work_order), params: {
        communication_work_order: {
          resolution_summary: "测试沟通拒绝"
        }
      }

      expect(CommunicationWorkOrderService::Rejecter).to have_received(:new).with(communication_work_order, hash_including(resolution_summary: "测试沟通拒绝"))
      expect(service_double).to have_received(:call)
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
      allow(service_double).to receive(:call).and_return(double(success?: true, fee_detail: fee_detail))

      post do_verify_fee_detail_admin_audit_work_order_path(audit_work_order), params: {
        fee_detail_id: fee_detail.id,
        verification_status: "verified",
        comment: "测试验证通过"
      }

      expect(FeeDetailVerificationService).to have_received(:new).with(fee_detail, hash_including(verification_status: "verified", comment: "测试验证通过"))
      expect(service_double).to have_received(:call)
      expect(response).to redirect_to(admin_audit_work_order_path(audit_work_order))
    end
  end

  describe "沟通记录添加表单" do
    it "GET /admin/communication_work_orders/:id/new_communication_record 返回成功响应" do
      get new_communication_record_admin_communication_work_order_path(communication_work_order)
      expect(response).to be_successful
    end

    it "POST /admin/communication_work_orders/:id/create_communication_record 处理添加沟通记录请求" do
      service_double = instance_double(CommunicationRecordService::Creator) # Assuming a service for communication records
      allow(CommunicationRecordService::Creator).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:call).and_return(double(success?: true, communication_record: build_stubbed(:communication_record)))

      post create_communication_record_admin_communication_work_order_path(communication_work_order), params: {
        communication_record: {
          content: "测试沟通内容",
          communicator_role: "财务人员",
          communicator_name: "张三",
          communication_method: "电话"
        }
      }

      expect(CommunicationRecordService::Creator).to have_received(:new).with(communication_work_order, hash_including(content: "测试沟通内容", communicator_role: "财务人员", communicator_name: "张三", communication_method: "电话"))
      expect(service_double).to have_received(:call)
      expect(response).to redirect_to(admin_communication_work_order_path(communication_work_order))
    end
  end
end