# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExpressReceiptWorkOrderRepository, type: :repository do
  let!(:reimbursement) { create(:reimbursement) }
  let!(:express_receipt1) do
    create(:express_receipt_work_order,
           reimbursement: reimbursement,
           tracking_number: 'SF1234567890',
           courier_name: 'SF Express',
           received_at: 1.day.ago,
           created_at: 1.day.ago)
  end
  
  let!(:express_receipt2) do
    create(:express_receipt_work_order,
           tracking_number: 'YTO9876543210',
           courier_name: 'YTO Express',
           received_at: Time.current,
           created_at: Time.current)
  end

  describe '.find and basic queries' do
    it 'finds express receipt work orders' do
      expect(described_class.find(express_receipt1.id)).to eq(express_receipt1)
      expect(described_class.find_by_id(express_receipt1.id)).to eq(express_receipt1)
      expect(described_class.find_by_ids([express_receipt1.id, express_receipt2.id]).count).to eq(2)
    end
  end

  describe '.by_tracking_number' do
    it 'returns receipt by tracking number' do
      result = described_class.by_tracking_number('SF1234567890')
      expect(result.pluck(:id)).to include(express_receipt1.id)
    end

    it 'finds by tracking number' do
      result = described_class.find_by_tracking_number('SF1234567890')
      expect(result).to eq(express_receipt1)
    end
  end

  describe '.by_filling_id' do
    it 'returns receipt by filling id' do
      result = described_class.by_filling_id(express_receipt1.filling_id)
      expect(result.pluck(:id)).to include(express_receipt1.id)
    end
  end

  describe '.by_courier_name' do
    it 'returns receipts by courier' do
      result = described_class.by_courier_name('SF Express')
      expect(result.pluck(:id)).to include(express_receipt1.id)
    end
  end

  describe '.for_reimbursement' do
    it 'returns receipts for specific reimbursement' do
      result = described_class.for_reimbursement(reimbursement.id)
      expect(result.pluck(:id)).to include(express_receipt1.id)
    end
  end

  describe 'received date queries' do
    it 'returns receipts received today' do
      result = described_class.received_today
      expect(result.pluck(:id)).to include(express_receipt2.id)
    end

    it 'returns receipts received this week' do
      result = described_class.received_this_week
      expect(result.count).to be >= 1
    end
  end

  describe 'creation date queries' do
    it 'returns receipts created today' do
      result = described_class.created_today
      expect(result.pluck(:id)).to include(express_receipt2.id)
    end
  end

  describe 'counting and aggregation' do
    it 'returns total count' do
      expect(described_class.total_count).to be >= 2
    end

    it 'groups by courier name' do
      result = described_class.courier_counts
      expect(result['SF Express']).to be >= 1
    end
  end

  describe 'ordering queries' do
    it 'returns recent receipts first' do
      result = described_class.recent
      expect(result.first.id).to eq(express_receipt2.id)
    end

    it 'returns recent received receipts' do
      result = described_class.recent_received
      expect(result.first.id).to eq(express_receipt2.id)
    end
  end

  describe 'existence checks' do
    it 'checks existence by id' do
      expect(described_class.exists?(id: express_receipt1.id)).to be true
      expect(described_class.exists?(id: 99_999)).to be false
    end

    it 'checks existence by tracking number' do
      expect(described_class.exists_by_tracking_number?('SF1234567890')).to be true
      expect(described_class.exists_by_tracking_number?('NONEXISTENT')).to be false
    end

    it 'checks existence by filling id' do
      expect(described_class.exists_by_filling_id?(express_receipt1.filling_id)).to be true
    end
  end

  describe 'optimizations' do
    it 'includes associations' do
      result = described_class.optimized_list
      expect(result).to be_present
    end
  end

  describe 'error handling' do
    it 'handles safe_find errors' do
      expect(described_class.safe_find(express_receipt1.id)).to eq(express_receipt1)
      expect(described_class.safe_find(99_999)).to be_nil
    end

    it 'handles safe_find_by_tracking_number errors' do
      expect(described_class.safe_find_by_tracking_number('SF1234567890')).to eq(express_receipt1)
      expect(described_class.safe_find_by_tracking_number('NONEXISTENT')).to be_nil
    end
  end
end
