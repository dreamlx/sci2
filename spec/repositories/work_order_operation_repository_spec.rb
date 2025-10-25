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

    it 'handles exceptions gracefully' do
      allow(WorkOrderOperation).to receive(:find_by).and_raise(StandardError.new('Database error'))
      result = described_class.safe_find(operation1.id)
      expect(result).to be_nil
    end
  end

  describe '.safe_find_by_id' do
    it 'returns operation when found' do
      result = described_class.safe_find_by_id(operation1.id)
      expect(result).to eq(operation1)
    end

    it 'returns nil when not found' do
      result = described_class.safe_find_by_id(99_999)
      expect(result).to be_nil
    end

    it 'handles exceptions gracefully' do
      allow(WorkOrderOperation).to receive(:find_by).and_raise(StandardError.new('Database error'))
      result = described_class.safe_find_by_id(operation1.id)
      expect(result).to be_nil
    end
  end

  describe '.find_by_ids' do
    it 'returns operations with specified ids' do
      result = described_class.find_by_ids([operation1.id, operation2.id])
      expect(result.pluck(:id)).to match_array([operation1.id, operation2.id])
    end

    it 'returns empty when no operations match' do
      result = described_class.find_by_ids([99_999, 88_888])
      expect(result).to be_empty
    end
  end

  describe '.for_work_order' do
    it 'returns operations for work order object' do
      result = described_class.for_work_order(work_order)
      expect(result.count).to eq(2)
      expect(result.pluck(:id)).to match_array([operation1.id, operation2.id])
    end
  end

  describe '.by_admin_user_id' do
    it 'returns operations for specific admin user by id' do
      result = described_class.by_admin_user_id(admin_user.id)
      expect(result.count).to eq(2)
      expect(result.pluck(:id)).to match_array([operation1.id, operation2.id])
    end
  end

  describe 'operation type specific queries' do
    describe '.create_operations' do
      it 'returns only create type operations' do
        result = described_class.create_operations
        expect(result.count).to eq(1)
        expect(result.first.operation_type).to eq('create')
      end
    end

    describe '.update_operations' do
      it 'returns only update type operations' do
        result = described_class.update_operations
        expect(result.count).to eq(1)
        expect(result.first.operation_type).to eq('update')
      end
    end

    describe '.status_change_operations' do
      let!(:status_change_op) do
        create(:work_order_operation,
               work_order: work_order,
               operation_type: WorkOrderOperation::OPERATION_TYPE_STATUS_CHANGE)
      end

      it 'returns only status change operations' do
        result = described_class.status_change_operations
        expect(result.pluck(:id)).to include(status_change_op.id)
        expect(result.all? { |op| op.operation_type == 'status_change' }).to be true
      end
    end

    describe '.remove_problem_operations' do
      let!(:remove_op) do
        create(:work_order_operation,
               work_order: work_order,
               operation_type: WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM)
      end

      it 'returns only remove problem operations' do
        result = described_class.remove_problem_operations
        expect(result.pluck(:id)).to include(remove_op.id)
        expect(result.all? { |op| op.operation_type == 'remove_problem' }).to be true
      end
    end

    describe '.modify_problem_operations' do
      let!(:modify_op) do
        create(:work_order_operation,
               work_order: work_order,
               operation_type: WorkOrderOperation::OPERATION_TYPE_MODIFY_PROBLEM)
      end

      it 'returns only modify problem operations' do
        result = described_class.modify_problem_operations
        expect(result.pluck(:id)).to include(modify_op.id)
        expect(result.all? { |op| op.operation_type == 'modify_problem' }).to be true
      end
    end
  end

  describe 'date range queries' do
    describe '.created_this_week' do
      it 'returns operations created this week' do
        result = described_class.created_this_week
        expect(result.count).to be >= 2
      end
    end

    describe '.created_this_month' do
      it 'returns operations created this month' do
        result = described_class.created_this_month
        expect(result.count).to be >= 2
      end
    end

    describe '.by_date_range' do
      it 'returns operations within date range' do
        start_date = 3.days.ago
        end_date = Time.current
        result = described_class.by_date_range(start_date, end_date)
        expect(result.count).to be >= 2
      end

      it 'returns empty when no operations in range' do
        start_date = 1.year.ago
        end_date = 6.months.ago
        result = described_class.by_date_range(start_date, end_date)
        expect(result).to be_empty
      end
    end
  end

  describe '.latest_for_work_order' do
    it 'returns latest operations for work order with limit' do
      result = described_class.latest_for_work_order(work_order.id, 1)
      expect(result.count).to eq(1)
      expect(result.first.id).to eq(operation1.id)
    end

    it 'orders by created_at descending' do
      result = described_class.latest_for_work_order(work_order.id, 5)
      timestamps = result.map(&:created_at)
      expect(timestamps).to eq(timestamps.sort.reverse)
    end
  end

  describe '.admin_user_counts' do
    it 'returns counts grouped by admin user' do
      result = described_class.admin_user_counts
      expect(result[admin_user.id]).to eq(2)
    end
  end

  describe '.count_by_admin_user' do
    it 'returns count of operations for admin user' do
      result = described_class.count_by_admin_user(admin_user.id)
      expect(result).to eq(2)
    end
  end

  describe '.page' do
    before do
      3.times { create(:work_order_operation, work_order: work_order) }
    end

    it 'returns paginated results' do
      result = described_class.page(1, 2)
      expect(result.count).to eq(2)
    end

    it 'returns second page correctly' do
      result = described_class.page(2, 2)
      expect(result.count).to be >= 1
    end
  end

  describe '.exists_for_work_order?' do
    it 'returns true when operations exist for work order' do
      result = described_class.exists_for_work_order?(work_order.id)
      expect(result).to be true
    end

    it 'returns false when no operations exist for work order' do
      result = described_class.exists_for_work_order?(99_999)
      expect(result).to be false
    end
  end

  describe '.select_fields' do
    it 'selects only specified fields' do
      result = described_class.select_fields(%i[id work_order_id])
      expect(result.first.attributes.keys).to include('id', 'work_order_id')
    end
  end

  describe '.optimized_list' do
    it 'eager loads associations' do
      result = described_class.optimized_list
      expect { result.first.work_order }.not_to raise_error
      expect { result.first.admin_user }.not_to raise_error
    end
  end

  describe '.with_associations' do
    it 'includes work_order and admin_user associations' do
      result = described_class.with_associations
      expect { result.first.work_order }.not_to raise_error
      expect { result.first.admin_user }.not_to raise_error
    end
  end
end