# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkOrderOperationRepository, type: :repository do
  # Use more specific test data setup to ensure isolation
  let!(:work_order) { create(:audit_work_order) }
  let!(:admin_user) { create(:admin_user, email: "test-#{SecureRandom.hex(4)}@example.com") }
  let!(:operation1) do
    create(:work_order_operation,
           work_order: work_order,
           admin_user: admin_user,
           operation_type: 'create',
           details: "Test create operation #{SecureRandom.hex(4)}",
           created_at: 1.day.ago)
  end
  let!(:operation2) do
    create(:work_order_operation,
           work_order: work_order,
           admin_user: admin_user,
           operation_type: 'update',
           details: "Test update operation #{SecureRandom.hex(4)}",
           created_at: 2.days.ago)
  end

  # Ensure clean test data before each test
  before do
    WorkOrderOperation.where.not(id: [operation1&.id, operation2&.id].compact).delete_all
  end

  describe '.find' do
    it 'returns operation when found' do
      result = described_class.find(operation1.id)
      expect(result).to eq(operation1)
    end

    it 'returns nil when not found' do
      result = described_class.find(99_999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_id' do
    it 'returns operation when found' do
      result = described_class.find_by_id(operation1.id)
      expect(result).to eq(operation1)
    end

    it 'returns nil when not found' do
      result = described_class.find_by_id(99_999)
      expect(result).to be_nil
    end
  end

  describe '.by_work_order' do
    it 'returns operations for specific work order' do
      result = described_class.by_work_order(work_order.id)
      expect(result.count).to eq(2)
      expect(result.pluck(:id)).to match_array([operation1.id, operation2.id])
    end
  end

  describe '.by_admin_user' do
    it 'returns operations for specific admin user' do
      result = described_class.by_admin_user(admin_user.id)
      expect(result.count).to eq(2)
      expect(result.pluck(:id)).to match_array([operation1.id, operation2.id])
    end
  end

  describe '.by_operation_type' do
    it 'returns operations with specified operation type' do
      result = described_class.by_operation_type('create')
      expect(result.count).to eq(1)
      expect(result.first.id).to eq(operation1.id)
      expect(result.first.operation_type).to eq('create')
    end
  end

  describe '.created_today' do
    it 'returns operations created today' do
      today_operation = create(:work_order_operation,
                              operation_type: 'status_change',
                              details: "Today operation #{SecureRandom.hex(4)}",
                              created_at: Time.current)
      result = described_class.created_today
      expect(result.pluck(:id)).to include(today_operation.id)
    end
  end

  describe '.recent' do
    it 'returns most recent operations' do
      recent_operation = create(:work_order_operation,
                               operation_type: 'remove_problem',
                               details: "Recent operation #{SecureRandom.hex(4)}",
                               created_at: 1.hour.from_now)
      result = described_class.recent(3)
      expect(result.first.id).to eq(recent_operation.id)
      expect(result.count).to eq(3)
    end
  end

  describe '.operation_type_counts' do
    it 'returns counts grouped by operation type' do
      result = described_class.operation_type_counts
      expect(result['create']).to eq(1)
      expect(result['update']).to eq(1)
    end
  end

  describe '.count_by_work_order' do
    it 'returns count of operations for work order' do
      result = described_class.count_by_work_order(work_order.id)
      expect(result).to eq(2)
    end
  end

  describe '.search_by_details' do
    it 'returns operations matching details pattern' do
      operation1.update!(details: '测试操作详情')
      result = described_class.search_by_details('测试')
      expect(result).to include(operation1)
    end

    it 'returns empty when no details match' do
      result = described_class.search_by_details('不存在的关键词')
      expect(result).to be_empty
    end
  end

  describe '.exists?' do
    it 'returns true when operation exists' do
      result = described_class.exists?(id: operation1.id)
      expect(result).to be true
    end

    it 'returns false when operation does not exist' do
      result = described_class.exists?(id: 99_999)
      expect(result).to be false
    end
  end

  describe '.safe_find' do
    it 'returns operation when found' do
      result = described_class.safe_find(operation1.id)
      expect(result).to eq(operation1)
    end

    it 'returns nil when not found' do
      result = described_class.safe_find(99_999)
      expect(result).to be_nil
    end
  end
end