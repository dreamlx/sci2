# spec/services/optimized_reimbursement_import_service_spec.rb
require 'rails_helper'

RSpec.describe OptimizedReimbursementImportService do
  let(:admin_user) { create(:admin_user) }
  let(:file) do
    file = double('file')
    allow(file).to receive(:path).and_return('test_reimbursements.csv')
    allow(file).to receive(:present?).and_return(true)
    file
  end
  let(:service) { described_class.new(file, admin_user) }

  describe '#batch_update_statuses' do
    let(:validated_data) do
      [
        { invoice_number: 'R202501001', external_status: '已付款' },
        { invoice_number: 'R202501002', external_status: '待付款' },
        { invoice_number: 'R202501003', external_status: '审批中' }
      ]
    end

    before do
      # Create test reimbursements
      create(:reimbursement, invoice_number: 'R202501001', status: Reimbursement::STATUS_PENDING, external_status: '处理中', manual_override: false)
      create(:reimbursement, invoice_number: 'R202501002', status: Reimbursement::STATUS_PROCESSING, external_status: '处理中', manual_override: false)
      create(:reimbursement, invoice_number: 'R202501003', status: Reimbursement::STATUS_PENDING, external_status: '处理中', manual_override: false)
    end

    it 'updates status to closed for reimbursements with paid external status' do
      service.batch_update_statuses(validated_data)

      reimbursement1 = Reimbursement.find_by(invoice_number: 'R202501001')
      expect(reimbursement1.status).to eq(Reimbursement::STATUS_CLOSED)
      expect(reimbursement1.external_status).to eq('已付款')

      reimbursement2 = Reimbursement.find_by(invoice_number: 'R202501002')
      expect(reimbursement2.status).to eq(Reimbursement::STATUS_CLOSED)
      expect(reimbursement2.external_status).to eq('待付款')
    end

    it 'does not update status for reimbursements with non-paid external status' do
      service.batch_update_statuses(validated_data)

      reimbursement3 = Reimbursement.find_by(invoice_number: 'R202501003')
      expect(reimbursement3.status).to eq(Reimbursement::STATUS_PENDING) # Should remain pending
      expect(reimbursement3.external_status).to eq('审批中')
    end

    it 'respects manual override flag' do
      # Create a reimbursement with manual override enabled
      create(:reimbursement, invoice_number: 'R202501004', status: Reimbursement::STATUS_PROCESSING, external_status: '处理中', manual_override: true)
      validated_data << { invoice_number: 'R202501004', external_status: '已付款' }

      service.batch_update_statuses(validated_data)

      reimbursement4 = Reimbursement.find_by(invoice_number: 'R202501004')
      expect(reimbursement4.status).to eq(Reimbursement::STATUS_PROCESSING) # Should remain unchanged
      expect(reimbursement4.external_status).to eq('已付款')
    end

    it 'only updates when status actually changes' do
      # Create a reimbursement that already has closed status
      create(:reimbursement, invoice_number: 'R202501005', status: Reimbursement::STATUS_CLOSED, external_status: '已付款', manual_override: false)
      validated_data << { invoice_number: 'R202501005', external_status: '已付款' }

      expect do
        service.batch_update_statuses(validated_data)
      end.not_to change { Reimbursement.find_by(invoice_number: 'R202501005').status }
    end
  end
end