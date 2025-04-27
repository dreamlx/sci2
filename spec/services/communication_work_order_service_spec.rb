require 'rails_helper'

RSpec.describe CommunicationWorkOrderService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement, status: 'processing') }
  let(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'communication_needed') }
  let(:work_order) { create(:communication_work_order, audit_work_order: audit_work_order, status: 'open') }
  let(:service) { CommunicationWorkOrderService.new(work_order, admin_user) }

  describe '#start_communication' do
    it 'starts communication for the work order' do
      expect(service.start_communication('开始沟通')).to be_truthy
      expect(work_order.reload.status).to eq('in_progress')
    end
  end

  describe '#resolve' do
    it 'resolves the work order' do
      expect(service.resolve('问题已解决')).to be_truthy
      expect(work_order.reload.status).to eq('resolved')
    end
  end

  describe '#mark_unresolved' do
    it 'marks the work order as unresolved' do
      expect(service.mark_unresolved('问题未解决')).to be_truthy
      expect(work_order.reload.status).to eq('unresolved')
    end
  end

  describe '#close' do
    it 'closes the work order' do
      expect(service.close('沟通结束')).to be_truthy
      expect(work_order.reload.status).to eq('closed')
    end
  end

  describe '#add_communication_record' do
    it 'adds a communication record' do
      expect {
        service.add_communication_record('沟通内容', ['attachment1.pdf', 'attachment2.pdf'])
      }.to change(CommunicationRecord, :count).by(1)
    end
  end

  describe '#resolve_fee_detail_issue' do
    let(:fee_detail) { create(:fee_detail, reimbursement: reimbursement) }
    let(:fee_detail_selection) { create(:fee_detail_selection, fee_detail: fee_detail, communication_work_order: work_order, verification_status: 'problematic') }

    it 'resolves the fee detail issue' do
      expect(service.resolve_fee_detail_issue(fee_detail.id, '问题已解决')).to be_truthy
      expect(fee_detail_selection.reload.verification_status).to eq('resolved')
    end
  end
end