require 'rails_helper'

RSpec.describe 'Admin::AuditWorkOrders', type: :request do
  let!(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement) }
  let!(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  let!(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'pending') }

  before do
    sign_in admin_user
  end

  describe 'GET /admin/audit_work_orders' do
    it '返回成功响应' do
      get admin_audit_work_orders_path
      expect(response).to be_successful
    end
  end

  describe 'POST /admin/audit_work_orders' do
    let!(:fee_detail1) { create(:fee_detail, document_number: reimbursement.invoice_number) }
    let!(:fee_detail2) { create(:fee_detail, document_number: reimbursement.invoice_number) }

    it '创建新的审核工单' do
      audit_work_order_params = attributes_for(:audit_work_order,
                                               reimbursement_id: reimbursement.id,
                                               fee_detail_ids: [fee_detail1.id, fee_detail2.id],
                                               problem_type: '发票问题',
                                               remark: '测试备注')
      expect do
        post admin_audit_work_orders_path, params: { audit_work_order: audit_work_order_params }
      end.to change(AuditWorkOrder, :count).by(1)
                                           .and change(FeeDetailSelection, :count).by(2)

      expect(response).to redirect_to(admin_audit_work_order_path(AuditWorkOrder.last))
      expect(AuditWorkOrder.last.problem_type).to eq('发票问题')

      # 验证FeeDetailSelection记录
      created_work_order = AuditWorkOrder.last
      expect(FeeDetailSelection.where(
        work_order_id: created_work_order.id,
        work_order_type: 'AuditWorkOrder'
      ).count).to eq(2)
    end
  end

  describe 'PUT /admin/audit_work_orders/:id' do
    it '更新审核工单' do
      put admin_audit_work_order_path(audit_work_order), params: {
        audit_work_order: { remark: 'Updated Remark', processing_opinion: '可以通过' }
      }
      audit_work_order.reload
      expect(audit_work_order.remark).to eq('Updated Remark')
      expect(audit_work_order.processing_opinion).to eq('可以通过')
      expect(response).to redirect_to(admin_audit_work_order_path(audit_work_order))
    end
  end

  describe 'GET /admin/audit_work_orders/:id' do
    it '返回成功响应' do
      get admin_audit_work_order_path(audit_work_order)
      expect(response).to be_successful
    end
  end

  describe 'PUT /admin/audit_work_orders/:id/start_processing' do
    it '更新工单状态为 processing' do
      # 模拟服务调用成功
      service_double = instance_double(AuditWorkOrderService, start_processing: true)
      expect(AuditWorkOrderService).to receive(:new).with(audit_work_order, admin_user).and_return(service_double)
      expect(service_double).to receive(:start_processing) # 检查是否调用了服务方法

      put start_processing_admin_audit_work_order_path(audit_work_order)
      expect(response).to redirect_to(admin_audit_work_order_path(audit_work_order))
      follow_redirect!
      expect(response.body).to include('工单已开始处理')
    end

    it '处理服务调用失败' do
      # 模拟服务调用失败
      service_double = instance_double(AuditWorkOrderService, start_processing: false)
      allow(audit_work_order).to receive_message_chain(:errors, :full_messages, :join).and_return('Service Error')
      expect(AuditWorkOrderService).to receive(:new).with(audit_work_order, admin_user).and_return(service_double)
      expect(service_double).to receive(:start_processing)

      put start_processing_admin_audit_work_order_path(audit_work_order)
      expect(response).to redirect_to(admin_audit_work_order_path(audit_work_order))
      follow_redirect!
      expect(response.body).to include('操作失败:')
    end
  end

  describe 'GET /admin/audit_work_orders/:id/approve' do
    it '返回成功响应' do
      # 先将工单状态设为processing
      audit_work_order.update(status: 'processing')

      get approve_admin_audit_work_order_path(audit_work_order)
      expect(response).to be_successful
    end
  end

  describe 'GET /admin/audit_work_orders/:id/reject' do
    it '返回成功响应' do
      # 先将工单状态设为processing
      audit_work_order.update(status: 'processing')

      get reject_admin_audit_work_order_path(audit_work_order)
      expect(response).to be_successful
    end
  end

  describe 'POST /admin/audit_work_orders/:id/do_approve' do
    context '从processing状态审核' do
      before do
        audit_work_order.update(status: 'processing')
      end

      it '审核通过工单' do
        # 模拟服务调用成功
        service_double = instance_double(AuditWorkOrderService, approve: true)
        expect(AuditWorkOrderService).to receive(:new).with(audit_work_order, admin_user).and_return(service_double)
        expect(service_double).to receive(:approve).with(hash_including(audit_comment: '审核通过测试'))

        post do_approve_admin_audit_work_order_path(audit_work_order), params: {
          audit_work_order: { audit_comment: '审核通过测试' }
        }
        expect(response).to redirect_to(admin_audit_work_order_path(audit_work_order))
        follow_redirect!
        expect(response.body).to include('审核已通过')
      end
    end

    context '从pending状态直接审核' do
      it '审核通过工单' do
        # 模拟服务调用成功
        service_double = instance_double(AuditWorkOrderService, approve: true)
        expect(AuditWorkOrderService).to receive(:new).with(audit_work_order, admin_user).and_return(service_double)
        expect(service_double).to receive(:approve).with(hash_including(audit_comment: '直接审核通过测试'))

        post do_approve_admin_audit_work_order_path(audit_work_order), params: {
          audit_work_order: { audit_comment: '直接审核通过测试' }
        }
        expect(response).to redirect_to(admin_audit_work_order_path(audit_work_order))
        follow_redirect!
        expect(response.body).to include('审核已通过')
      end
    end

    it '处理服务调用失败' do
      # 先将工单状态设为processing
      audit_work_order.update(status: 'processing')

      # 模拟服务调用失败
      service_double = instance_double(AuditWorkOrderService, approve: false)
      allow(audit_work_order).to receive_message_chain(:errors, :full_messages, :join).and_return('Service Error')
      expect(AuditWorkOrderService).to receive(:new).with(audit_work_order, admin_user).and_return(service_double)
      expect(service_double).to receive(:approve).with(hash_including(audit_comment: '审核通过测试'))

      post do_approve_admin_audit_work_order_path(audit_work_order), params: {
        audit_work_order: { audit_comment: '审核通过测试' }
      }
      expect(response).to render_template(:approve) # 失败时应该渲染 approve 模板
      expect(response.body).to include('操作失败:')
    end
  end

  describe 'POST /admin/audit_work_orders/:id/do_reject' do
    it '审核拒绝工单' do
      # 先将工单状态设为processing
      audit_work_order.update(status: 'processing')

      # 模拟服务调用成功
      service_double = instance_double(AuditWorkOrderService, reject: true)
      expect(AuditWorkOrderService).to receive(:new).with(audit_work_order, admin_user).and_return(service_double)
      expect(service_double).to receive(:reject).with(hash_including(audit_comment: '审核拒绝测试')) # 检查是否调用了服务方法并传递参数

      post do_reject_admin_audit_work_order_path(audit_work_order), params: {
        audit_work_order: { audit_comment: '审核拒绝测试' }
      }
      expect(response).to redirect_to(admin_audit_work_order_path(audit_work_order))
      follow_redirect!
      expect(response.body).to include('审核已拒绝')
    end

    it '处理服务调用失败' do
      # 先将工单状态设为processing
      audit_work_order.update(status: 'processing')

      # 模拟服务调用失败
      service_double = instance_double(AuditWorkOrderService, reject: false)
      allow(audit_work_order).to receive_message_chain(:errors, :full_messages, :join).and_return('Service Error')
      expect(AuditWorkOrderService).to receive(:new).with(audit_work_order, admin_user).and_return(service_double)
      expect(service_double).to receive(:reject).with(hash_including(audit_comment: '审核拒绝测试'))

      post do_reject_admin_audit_work_order_path(audit_work_order), params: {
        audit_work_order: { audit_comment: '审核拒绝测试' }
      }
      expect(response).to render_template(:reject) # 失败时应该渲染 reject 模板
      expect(response.body).to include('操作失败:')
    end
  end

  describe 'POST /admin/audit_work_orders/:id/do_verify_fee_detail' do
    let!(:fee_detail_selection) { create(:fee_detail_selection, work_order: audit_work_order, fee_detail: fee_detail) }

    it '更新费用明细验证状态' do
      # 模拟服务调用成功
      service_double = instance_double(AuditWorkOrderService, update_fee_detail_verification: true)
      expect(AuditWorkOrderService).to receive(:new).with(audit_work_order, admin_user).and_return(service_double)
      expect(service_double).to receive(:update_fee_detail_verification).with(fee_detail.id.to_s, 'verified', '测试验证意见') # 检查是否调用了服务方法并传递参数

      post do_verify_fee_detail_admin_audit_work_order_path(audit_work_order), params: {
        fee_detail_id: fee_detail.id,
        verification_status: 'verified',
        comment: '测试验证意见'
      }
      expect(response).to redirect_to(admin_audit_work_order_path(audit_work_order))
      follow_redirect!
      expect(response.body).to include("费用明细 ##{fee_detail.id} 状态已更新")
    end

    it '处理服务调用失败' do
      # 模拟服务调用失败
      service_double = instance_double(AuditWorkOrderService, update_fee_detail_verification: false)
      allow(audit_work_order).to receive_message_chain(:errors, :full_messages, :join).and_return('Service Error')
      expect(AuditWorkOrderService).to receive(:new).with(audit_work_order, admin_user).and_return(service_double)
      expect(service_double).to receive(:update_fee_detail_verification).with(fee_detail.id.to_s, 'verified', '测试验证意见')

      post do_verify_fee_detail_admin_audit_work_order_path(audit_work_order), params: {
        fee_detail_id: fee_detail.id,
        verification_status: 'verified',
        comment: '测试验证意见'
      }
      # 失败时应该渲染 verify_fee_detail 模板 (需要设置 @work_order 和 @fee_detail)
      expect(response).to render_template('admin/shared/verify_fee_detail')
      expect(response.body).to include("费用明细 ##{fee_detail.id} 更新失败:")
    end
  end
end
