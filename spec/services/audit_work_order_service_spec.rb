require 'rails_helper'

RSpec.describe AuditWorkOrderService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement, status: 'processing') }
  let(:work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'pending') }
  let(:service) { AuditWorkOrderService.new(work_order, admin_user) }

  describe '#start_processing' do
    it 'starts processing the work order' do
      expect(service.start_processing('开始处理')).to be_truthy
      expect(work_order.reload.status).to eq('processing')
    end

    it 'does not start processing if the work order is not pending' do
      work_order.update(status: 'processing')
      expect(service.start_processing('重新开始处理')).to be_falsey
      expect(work_order.reload.status).to eq('processing')
    end
  end

  describe '#start_audit' do
    it 'starts auditing the work order' do
      expect(service.start_audit('开始审核')).to be_truthy
      expect(work_order.reload.status).to eq('auditing')
    end
  end

  describe '#approve' do
    it 'approves the work order' do
      expect(service.approve('审核通过')).to be_truthy
      expect(work_order.reload.status).to eq('approved')
    end
  end

  describe '#reject' do
    it 'rejects the work order' do
      expect(service.reject('审核拒绝')).to be_truthy
      expect(work_order.reload.status).to eq('rejected')
    end
  end

  describe '#need_communication' do
    it 'marks the work order as needing communication' do
      expect(service.need_communication('需要进一步沟通')).to be_truthy
      expect(work_order.reload.status).to eq('communication_needed')
      expect(CommunicationWorkOrder.exists?(audit_work_order_id: work_order.id)).to be_truthy
    end
  end

  describe '#resume_audit' do
    it 'resumes auditing the work order' do
      work_order.update(status: 'communication_needed')
      expect(service.resume_audit('继续审核')).to be_truthy
      expect(work_order.reload.status).to eq('auditing')
    end
  end

  describe '#complete' do
    it 'completes the work order' do
      expect(service.complete('审核完成')).to be_truthy
      expect(work_order.reload.status).to eq('completed')
    end
  end
end