require 'rails_helper'

RSpec.describe WorkOrderStatusChangeService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement, status: 'processing') }
  let(:work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'pending') }
  let(:service) { WorkOrderStatusChangeService.new(admin_user) }

  describe '#record_status_change' do
    it 'records a status change for the work order' do
      expect(service.record_status_change(work_order, 'auditing', '开始审核')).to be_truthy
      expect(work_order.reload.status).to eq('auditing')
    end
  end

  describe '#get_status_changes' do
    before do
      service.record_status_change(work_order, 'auditing', '开始审核')
      service.record_status_change(work_order, 'approved', '审核通过')
    end

    it 'returns the status change history of a work order' do
      status_changes = service.get_status_changes(work_order)
      expect(status_changes.size).to eq(2)
      expect(status_changes.first.new_status).to eq('approved')
      expect(status_changes.last.new_status).to eq('auditing')
    end
  end
end