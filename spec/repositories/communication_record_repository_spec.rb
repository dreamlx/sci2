# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CommunicationRecordRepository do
  let(:communication_work_order) { create(:communication_work_order) }
  let(:communication_work_order2) { create(:communication_work_order) }

  let!(:record1) do
    create(:communication_record,
           communication_work_order: communication_work_order,
           communicator_role: '财务人员',
           communication_method: '电话',
           content: '第一次沟通记录',
           recorded_at: 2.days.ago)
  end

  let!(:record2) do
    create(:communication_record,
           communication_work_order: communication_work_order,
           communicator_role: '申请人',
           communication_method: '邮件',
           content: '第二次沟通记录',
           recorded_at: 1.day.ago)
  end

  let!(:record3) do
    create(:communication_record,
           communication_work_order: communication_work_order2,
           communicator_role: '财务人员',
           communication_method: '电话',
           content: '第三次沟通记录',
           recorded_at: Time.current)
  end

  describe '.find' do
    it 'finds record by id' do
      result = described_class.find(record1.id)
      expect(result).to eq(record1)
    end

    it 'returns nil when record not found' do
      result = described_class.find(99999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_id' do
    it 'finds record by id' do
      result = described_class.find_by_id(record1.id)
      expect(result).to eq(record1)
    end

    it 'returns nil when record not found' do
      result = described_class.find_by_id(99999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_ids' do
    it 'finds multiple records by ids' do
      results = described_class.find_by_ids([record1.id, record2.id])
      expect(results.pluck(:id)).to contain_exactly(record1.id, record2.id)
    end

    it 'returns empty array for invalid ids' do
      results = described_class.find_by_ids([99999, 88888])
      expect(results).to be_empty
    end
  end

  describe '.by_communication_work_order' do
    it 'finds all records for a communication work order' do
      results = described_class.by_communication_work_order(communication_work_order.id)
      expect(results.pluck(:id)).to contain_exactly(record1.id, record2.id)
    end

    it 'returns empty array when no records found' do
      results = described_class.by_communication_work_order(99999)
      expect(results).to be_empty
    end
  end

  describe '.for_communication_work_order' do
    it 'finds all records for a communication work order object' do
      results = described_class.for_communication_work_order(communication_work_order)
      expect(results.pluck(:id)).to contain_exactly(record1.id, record2.id)
    end
  end

  describe '.by_communicator_role' do
    it 'finds all records by communicator role' do
      results = described_class.by_communicator_role('财务人员')
      expect(results.pluck(:id)).to contain_exactly(record1.id, record3.id)
    end

    it 'returns empty array when no records found' do
      results = described_class.by_communicator_role('不存在的角色')
      expect(results).to be_empty
    end
  end

  describe '.by_communication_method' do
    it 'finds all records by communication method' do
      results = described_class.by_communication_method('电话')
      expect(results.pluck(:id)).to contain_exactly(record1.id, record3.id)
    end

    it 'returns empty array when no records found' do
      results = described_class.by_communication_method('不存在的方法')
      expect(results).to be_empty
    end
  end

  describe '.by_communicator_name' do
    let!(:record4) do
      create(:communication_record,
             communication_work_order: communication_work_order,
             communicator_name: '张三')
    end

    it 'finds all records by communicator name' do
      results = described_class.by_communicator_name('张三')
      expect(results.pluck(:id)).to include(record4.id)
    end
  end

  describe 'date-based queries' do
    describe '.recorded_today' do
      it 'finds records recorded today' do
        results = described_class.recorded_today
        expect(results.pluck(:id)).to include(record3.id)
      end
    end

    describe '.recorded_this_week' do
      it 'finds records recorded this week' do
        results = described_class.recorded_this_week
        expect(results.count).to be >= 1
      end
    end

    describe '.recorded_this_month' do
      it 'finds records recorded this month' do
        results = described_class.recorded_this_month
        expect(results.pluck(:id)).to contain_exactly(record1.id, record2.id, record3.id)
      end
    end

    describe '.by_date_range' do
      it 'finds records within date range' do
        start_date = 3.days.ago
        end_date = Time.current
        results = described_class.by_date_range(start_date, end_date)
        expect(results.pluck(:id)).to contain_exactly(record1.id, record2.id, record3.id)
      end

      it 'returns empty array when no records in range' do
        start_date = 1.year.ago
        end_date = 6.months.ago
        results = described_class.by_date_range(start_date, end_date)
        expect(results).to be_empty
      end
    end
  end

  describe '.recent' do
    it 'finds recent records with default limit' do
      results = described_class.recent(2)
      expect(results.count).to eq(2)
      expect(results.first.id).to eq(record3.id)
    end

    it 'orders by recorded_at descending' do
      results = described_class.recent
      expect(results.first.recorded_at).to be >= results.last.recorded_at
    end
  end

  describe '.latest_for_work_order' do
    it 'finds latest records for a work order' do
      results = described_class.latest_for_work_order(communication_work_order.id, 2)
      expect(results.count).to eq(2)
      expect(results.first.id).to eq(record2.id)
    end

    it 'respects limit parameter' do
      results = described_class.latest_for_work_order(communication_work_order.id, 1)
      expect(results.count).to eq(1)
    end

    it 'orders by recorded_at descending' do
      results = described_class.latest_for_work_order(communication_work_order.id, 5)
      timestamps = results.map(&:recorded_at)
      expect(timestamps).to eq(timestamps.sort.reverse)
    end
  end

  describe '.search_content' do
    it 'finds records matching content query' do
      results = described_class.search_content('第一次')
      expect(results.pluck(:id)).to include(record1.id)
    end

    it 'returns empty array for blank query' do
      results = described_class.search_content('')
      expect(results).to be_empty
    end

    it 'returns empty array when no matches found' do
      results = described_class.search_content('不存在的内容')
      expect(results).to be_empty
    end
  end

  describe 'count and aggregation methods' do
    describe '.count_by_work_order' do
      it 'counts records for a work order' do
        count = described_class.count_by_work_order(communication_work_order.id)
        expect(count).to eq(2)
      end
    end

    describe '.count_by_role' do
      it 'counts records by role' do
        count = described_class.count_by_role('财务人员')
        expect(count).to eq(2)
      end
    end

    describe '.role_counts' do
      it 'counts records grouped by role' do
        results = described_class.role_counts
        expect(results['财务人员']).to eq(2)
        expect(results['申请人']).to eq(1)
      end
    end

    describe '.method_counts' do
      it 'counts records grouped by method' do
        results = described_class.method_counts
        expect(results['电话']).to eq(2)
        expect(results['邮件']).to eq(1)
      end
    end
  end

  describe '.exists?' do
    it 'returns true when record exists' do
      expect(described_class.exists?(id: record1.id)).to be true
    end

    it 'returns false when record does not exist' do
      expect(described_class.exists?(id: 99999)).to be false
    end
  end

  describe '.exists_by_id?' do
    it 'returns true when record exists' do
      expect(described_class.exists_by_id?(record1.id)).to be true
    end

    it 'returns false when record does not exist' do
      expect(described_class.exists_by_id?(99999)).to be false
    end
  end

  describe '.exists_for_work_order?' do
    it 'returns true when records exist for work order' do
      expect(described_class.exists_for_work_order?(communication_work_order.id)).to be true
    end

    it 'returns false when no records exist for work order' do
      expect(described_class.exists_for_work_order?(99999)).to be false
    end
  end

  describe '.with_associations' do
    it 'includes communication_work_order association' do
      results = described_class.with_associations
      expect { results.first.communication_work_order }.not_to raise_error
    end
  end

  describe '.optimized_list' do
    it 'returns optimized query with associations' do
      results = described_class.optimized_list
      expect { results.first.communication_work_order }.not_to raise_error
    end
  end

  describe '.select_fields' do
    it 'selects specific fields' do
      results = described_class.select_fields(%i[id content])
      expect(results.first.attributes.keys).to include('id', 'content')
    end
  end

  describe '.page' do
    before do
      3.times { create(:communication_record, communication_work_order: communication_work_order) }
    end

    it 'paginates results with default per_page' do
      results = described_class.page(1, 2)
      expect(results.count).to eq(2)
    end

    it 'returns second page of results' do
      results = described_class.page(2, 2)
      expect(results.count).to be >= 1
    end
  end

  describe '.where' do
    it 'finds records matching conditions' do
      results = described_class.where(communicator_role: '财务人员')
      expect(results.pluck(:id)).to contain_exactly(record1.id, record3.id)
    end
  end

  describe '.where_not' do
    it 'finds records not matching conditions' do
      results = described_class.where_not(communicator_role: '财务人员')
      expect(results.pluck(:id)).to include(record2.id)
    end
  end

  describe '.create' do
    it 'creates new record' do
      expect do
        described_class.create(
          communication_work_order: communication_work_order2,
          content: '新的沟通记录',
          communicator_role: '财务人员'
        )
      end.to change(CommunicationRecord, :count).by(1)
    end
  end

  describe '.create!' do
    it 'creates new record' do
      expect do
        described_class.create!(
          communication_work_order: communication_work_order2,
          content: '新的沟通记录',
          communicator_role: '财务人员'
        )
      end.to change(CommunicationRecord, :count).by(1)
    end

    it 'raises error on validation failure' do
      expect do
        described_class.create!(
          communication_work_order: nil,
          content: nil,
          communicator_role: nil
        )
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe '.batch_create' do
    let(:records) do
      [
        {
          communication_work_order: communication_work_order2,
          content: '批量记录1',
          communicator_role: '财务人员'
        },
        {
          communication_work_order: communication_work_order2,
          content: '批量记录2',
          communicator_role: '申请人'
        }
      ]
    end

    it 'creates multiple records' do
      expect do
        described_class.batch_create(records)
      end.to change(CommunicationRecord, :count).by(2)
    end

    it 'returns array of created records' do
      results = described_class.batch_create(records)
      expect(results.count).to eq(2)
      expect(results.all? { |r| r.is_a?(CommunicationRecord) }).to be true
    end
  end

  describe '.delete_all' do
    it 'deletes all records matching conditions' do
      expect do
        described_class.delete_all(communicator_role: '财务人员')
      end.to change(CommunicationRecord, :count).by(-2)
    end
  end

  describe '.safe_find' do
    it 'finds record safely' do
      result = described_class.safe_find(record1.id)
      expect(result).to eq(record1)
    end

    it 'returns nil on not found' do
      result = described_class.safe_find(99999)
      expect(result).to be_nil
    end

    it 'handles exceptions gracefully' do
      allow(CommunicationRecord).to receive(:find_by).and_raise(StandardError.new('Database error'))
      result = described_class.safe_find(record1.id)
      expect(result).to be_nil
    end
  end

  describe '.safe_find_by_id' do
    it 'finds record safely' do
      result = described_class.safe_find_by_id(record1.id)
      expect(result).to eq(record1)
    end

    it 'returns nil on not found' do
      result = described_class.safe_find_by_id(99999)
      expect(result).to be_nil
    end

    it 'handles exceptions gracefully' do
      allow(CommunicationRecord).to receive(:find_by).and_raise(StandardError.new('Database error'))
      result = described_class.safe_find_by_id(record1.id)
      expect(result).to be_nil
    end
  end

  describe 'sorting methods' do
    describe '.order_by_date' do
      it 'orders by recorded_at descending by default' do
        results = described_class.order_by_date(:desc)
        expect(results.first.id).to eq(record3.id)
      end

      it 'orders by recorded_at ascending when specified' do
        results = described_class.order_by_date(:asc)
        expect(results.first.id).to eq(record1.id)
      end
    end

    describe '.oldest_first' do
      it 'returns records ordered oldest first' do
        results = described_class.oldest_first
        expect(results.first.id).to eq(record1.id)
      end
    end

    describe '.newest_first' do
      it 'returns records ordered newest first' do
        results = described_class.newest_first
        expect(results.first.id).to eq(record3.id)
      end
    end
  end
end
