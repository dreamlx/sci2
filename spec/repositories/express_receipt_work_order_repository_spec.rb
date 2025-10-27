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

  # 使用共享测试示例
  it_behaves_like 'basic work order repository', ExpressReceiptWorkOrderRepository, ExpressReceiptWorkOrder, :express_receipt_work_order
  it_behaves_like 'intelligent status queries', ExpressReceiptWorkOrderRepository, ExpressReceiptWorkOrder

  # ExpressReceiptWorkOrder特有的测试用例

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

  # ExpressReceiptWorkOrder特有的测试用例
  describe 'tracking number queries' do
    describe '.by_tracking_number' do
      it 'returns receipt by tracking number' do
        result = described_class.by_tracking_number('SF1234567890')
        expect(result.pluck(:id)).to include(express_receipt1.id)
      end
    end

    describe '.find_by_tracking_number' do
      it 'finds by tracking number' do
        result = described_class.find_by_tracking_number('SF1234567890')
        expect(result).to eq(express_receipt1)
      end
    end

    describe '.safe_find_by_tracking_number' do
      it 'handles safe_find_by_tracking_number errors' do
        expect(described_class.safe_find_by_tracking_number('SF1234567890')).to eq(express_receipt1)
        expect(described_class.safe_find_by_tracking_number('NONEXISTENT')).to be_nil
      end
    end

    describe '.exists_by_tracking_number?' do
      it 'checks existence by tracking number' do
        expect(described_class.exists_by_tracking_number?('SF1234567890')).to be true
        expect(described_class.exists_by_tracking_number?('NONEXISTENT')).to be false
      end
    end
  end

  describe 'filling id queries' do
    describe '.by_filling_id' do
      it 'returns receipt by filling id' do
        result = described_class.by_filling_id(express_receipt1.filling_id)
        expect(result.pluck(:id)).to include(express_receipt1.id)
      end
    end

    describe '.exists_by_filling_id?' do
      it 'checks existence by filling id' do
        expect(described_class.exists_by_filling_id?(express_receipt1.filling_id)).to be true
      end
    end
  end

  describe 'courier name queries' do
    describe '.by_courier_name' do
      it 'returns receipts by courier' do
        result = described_class.by_courier_name('SF Express')
        expect(result.pluck(:id)).to include(express_receipt1.id)
      end
    end

    describe '.courier_counts' do
      it 'groups by courier name' do
        result = described_class.courier_counts
        expect(result['SF Express']).to be >= 1
      end
    end
  end

  describe 'received date queries' do
    describe '.received_today' do
      it 'returns receipts received today' do
        result = described_class.received_today
        expect(result.pluck(:id)).to include(express_receipt2.id)
      end
    end

    describe '.received_this_week' do
      it 'returns receipts received this week' do
        result = described_class.received_this_week
        expect(result.count).to be >= 1
      end
    end

    describe '.recent_received' do
      it 'returns recent received receipts' do
        result = described_class.recent_received
        expect(result.first.id).to eq(express_receipt2.id)
      end
    end
  end
end
