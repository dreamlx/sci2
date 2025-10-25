# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CommunicationWorkOrderRepository, type: :repository do
  let!(:reimbursement) { create(:reimbursement) }
  let!(:communication1) do
    create(:communication_work_order,
           reimbursement: reimbursement,
           communication_method: 'phone',
           audit_comment: 'Called customer to confirm details',
           status: 'completed',
           created_at: 1.day.ago)
  end
  
  let!(:communication2) do
    create(:communication_work_order,
           communication_method: 'email',
           audit_comment: 'Email sent regarding documentation',
           status: 'completed',
           created_at: Time.current)
  end

  describe '.find and basic queries' do
    it 'finds communication work orders' do
      expect(described_class.find(communication1.id)).to eq(communication1)
      expect(described_class.find_by_id(communication1.id)).to eq(communication1)
      expect(described_class.find_by_ids([communication1.id, communication2.id]).count).to eq(2)
    end
  end

  describe '.by_communication_method' do
    it 'returns communications by method' do
      result = described_class.by_communication_method('phone')
      expect(result.pluck(:id)).to include(communication1.id)
    end
  end

  describe '.status queries' do
    it 'returns completed communications' do
      result = described_class.completed
      expect(result.count).to be >= 2
    end
  end

  describe '.for_reimbursement' do
    it 'returns communications for specific reimbursement' do
      result = described_class.for_reimbursement(reimbursement.id)
      expect(result.pluck(:id)).to include(communication1.id)
    end
  end

  describe '.search_by_audit_comment' do
    it 'searches by comment text' do
      result = described_class.search_by_audit_comment('customer')
      expect(result.pluck(:id)).to include(communication1.id)
    end
  end

  describe 'date queries' do
    it 'returns records created today' do
      result = described_class.created_today
      expect(result.pluck(:id)).to include(communication2.id)
    end
  end

  describe 'counting and aggregation' do
    it 'returns total count' do
      expect(described_class.total_count).to be >= 2
    end

    it 'groups by communication method' do
      result = described_class.communication_method_counts
      expect(result['phone']).to be >= 1
    end
  end

  describe 'ordering and pagination' do
    it 'returns recent records first' do
      result = described_class.recent
      expect(result.first.id).to eq(communication2.id)
    end
  end

  describe 'existence checks' do
    it 'checks existence by id' do
      expect(described_class.exists?(id: communication1.id)).to be true
      expect(described_class.exists?(id: 99_999)).to be false
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
      expect(described_class.safe_find(communication1.id)).to eq(communication1)
      expect(described_class.safe_find(99_999)).to be_nil
    end
  end
end
