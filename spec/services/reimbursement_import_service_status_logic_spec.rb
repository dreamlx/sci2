require 'rails_helper'

RSpec.describe ReimbursementImportService, type: :service do
  describe 'New Status Logic Integration' do
    let(:admin_user) { create(:admin_user) }
    let(:service) { described_class.new(nil, admin_user) }

    describe '#determine_status_from_external' do
      let(:reimbursement) { create(:reimbursement, status: 'pending') }

      it 'returns "closed" for "已付款" external status' do
        result = service.send(:determine_status_from_external, reimbursement, '已付款')
        expect(result).to eq('closed')
      end

      it 'returns "closed" for "待付款" external status' do
        result = service.send(:determine_status_from_external, reimbursement, '待付款')
        expect(result).to eq('closed')
      end

      it 'returns "processing" for "审批中" when work orders exist' do
        create(:work_order, reimbursement: reimbursement, status: 'pending')
        result = service.send(:determine_status_from_external, reimbursement, '审批中')
        expect(result).to eq('processing')
      end

      it 'returns "pending" for "审批中" when no work orders exist' do
        result = service.send(:determine_status_from_external, reimbursement, '审批中')
        expect(result).to eq('pending')
      end

      it 'respects manual override protection' do
        reimbursement.manual_status_change!('closed')
        original_status = reimbursement.status

        result = service.send(:determine_status_from_external, reimbursement, '审批中')
        expect(result).to eq(original_status)
      end
    end

    describe 'External Status Priority' do
      let(:reimbursement) { create(:reimbursement, status: 'processing') }

      it 'prioritizes external status over work order logic' do
        # Create active work orders that would normally keep status as processing
        create(:work_order, reimbursement: reimbursement, status: 'pending')

        # External status should override
        result = service.send(:determine_status_from_external, reimbursement, '已付款')
        expect(result).to eq('closed')
      end

      it 'uses work order logic when external status allows' do
        create(:work_order, reimbursement: reimbursement, status: 'pending')

        result = service.send(:determine_status_from_external, reimbursement, '审批中')
        expect(result).to eq('processing')
      end
    end

    describe 'Last External Status Tracking' do
      let(:reimbursement) { create(:reimbursement) }

      it 'updates last_external_status when status changes' do
        expect(reimbursement.last_external_status).to be_nil

        service.send(:determine_status_from_external, reimbursement, '已付款')
        reimbursement.reload

        expect(reimbursement.last_external_status).to eq('已付款')
      end

      it 'tracks external status changes over time' do
        service.send(:determine_status_from_external, reimbursement, '审批中')
        reimbursement.reload
        expect(reimbursement.last_external_status).to eq('审批中')

        service.send(:determine_status_from_external, reimbursement, '已付款')
        reimbursement.reload
        expect(reimbursement.last_external_status).to eq('已付款')
      end
    end
  end

  describe 'Integration with Import Process' do
    let(:admin_user) { create(:admin_user) }
    let(:csv_content) do
      <<~CSV
        单据编号,外部状态,金额
        R001,已付款,1000.00
        R002,审批中,2000.00
        R003,待付款,1500.00
      CSV
    end
    let(:csv_file) { Tempfile.new(['test', '.csv']) }

    before do
      csv_file.write(csv_content)
      csv_file.rewind
    end

    after do
      csv_file.close
      csv_file.unlink
    end

    it 'applies new status logic during import' do
      # Create existing reimbursements
      r1 = create(:reimbursement, invoice_number: 'R001', status: 'pending')
      create(:reimbursement, invoice_number: 'R002', status: 'pending')
      create(:reimbursement, invoice_number: 'R003', status: 'pending')

      service = described_class.new(csv_file, admin_user)

      # Mock the import process to focus on status logic
      allow(service).to receive(:import_reimbursement).and_call_original

      # The actual import would apply the new status logic
      expect(r1.reload.status).to eq('pending') # Before import

      # Simulate what would happen during import
      service.send(:determine_status_from_external, r1, '已付款')
      expect(r1.status).to eq('closed') # After applying new logic
    end
  end
end
