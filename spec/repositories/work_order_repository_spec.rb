# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkOrderRepository, type: :repository do
  let!(:reimbursement) { create(:reimbursement, invoice_number: 'INV-001') }
  let!(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement) }
  let!(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement) }

  describe '.find' do
    it 'returns work order when found' do
      result = described_class.find(audit_work_order.id)
      expect(result).to eq(audit_work_order)
    end

    it 'returns nil when not found' do
      result = described_class.find(99_999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_id' do
    it 'returns work order when found' do
      result = described_class.find_by_id(audit_work_order.id)
      expect(result).to eq(audit_work_order)
    end

    it 'returns nil when not found' do
      result = described_class.find_by_id(99_999)
      expect(result).to be_nil
    end
  end

  describe '.for_reimbursement' do
    it 'returns work orders for specific reimbursement' do
      result = described_class.for_reimbursement(reimbursement)
      expect(result.count).to eq(2)
      expect(result).to include(audit_work_order, communication_work_order)
    end
  end

  describe '.audit_work_orders' do
    it 'returns only audit work orders' do
      result = described_class.audit_work_orders
      expect(result).to include(audit_work_order)
      expect(result).not_to include(communication_work_order)
    end
  end

  describe '.communication_work_orders' do
    it 'returns only communication work orders' do
      result = described_class.communication_work_orders
      expect(result).to include(communication_work_order)
      expect(result).not_to include(audit_work_order)
    end
  end

  describe '.type_counts' do
    it 'returns counts grouped by type' do
      result = described_class.type_counts
      expect(result['AuditWorkOrder']).to eq(1)
      expect(result['CommunicationWorkOrder']).to eq(1)
    end
  end

  describe '.recent' do
    it 'returns most recent work orders' do
      recent_order = create(:audit_work_order, created_at: 1.hour.from_now)
      result = described_class.recent(2)
      expect(result.first).to eq(recent_order)
      expect(result.count).to eq(2)
    end
  end

  describe '.safe_find' do
    it 'returns work order when found' do
      result = described_class.safe_find(audit_work_order.id)
      expect(result).to eq(audit_work_order)
    end

    it 'returns nil when not found' do
      result = described_class.safe_find(99_999)
      expect(result).to be_nil
    end
  end
end