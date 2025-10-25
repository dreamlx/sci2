# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkOrderProblemRepository do
  let(:admin_user) { create(:admin_user) }
  let(:work_order) { create(:express_receipt_work_order) }
  let(:problem_type1) { create(:problem_type) }
  let(:problem_type2) { create(:problem_type) }
  let!(:problem1) do
    Current.admin_user = admin_user
    create(:work_order_problem, work_order: work_order, problem_type: problem_type1)
  end
  let!(:problem2) do
    Current.admin_user = admin_user
    create(:work_order_problem, work_order: work_order, problem_type: problem_type2)
  end

  before do
    Current.admin_user = admin_user
  end

  describe '.find' do
    it 'finds work order problem by id' do
      result = described_class.find(problem1.id)
      expect(result).to eq(problem1)
    end

    it 'returns nil when record not found' do
      result = described_class.find(99999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_id' do
    it 'finds work order problem by id' do
      result = described_class.find_by_id(problem1.id)
      expect(result).to eq(problem1)
    end

    it 'returns nil when record not found' do
      result = described_class.find_by_id(99999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_work_order_id' do
    it 'finds all problems for a work order' do
      results = described_class.find_by_work_order_id(work_order.id)
      expect(results.pluck(:id)).to contain_exactly(problem1.id, problem2.id)
    end

    it 'returns empty array when no problems found' do
      results = described_class.find_by_work_order_id(99999)
      expect(results).to be_empty
    end
  end

  describe '.find_by_problem_type_id' do
    it 'finds all work orders with specific problem type' do
      results = described_class.find_by_problem_type_id(problem_type1.id)
      expect(results.pluck(:id)).to contain_exactly(problem1.id)
    end

    it 'returns empty array when no problems found' do
      results = described_class.find_by_problem_type_id(99999)
      expect(results).to be_empty
    end
  end

  describe '.find_by_ids' do
    it 'finds multiple problems by ids' do
      results = described_class.find_by_ids([problem1.id, problem2.id])
      expect(results.pluck(:id)).to contain_exactly(problem1.id, problem2.id)
    end

    it 'returns empty array for invalid ids' do
      results = described_class.find_by_ids([99999, 88888])
      expect(results).to be_empty
    end
  end

  describe '.find_by_work_order_ids' do
    let(:work_order2) { create(:express_receipt_work_order) }
    let!(:problem3) { create(:work_order_problem, work_order: work_order2, problem_type: problem_type1) }

    it 'finds all problems for multiple work orders' do
      results = described_class.find_by_work_order_ids([work_order.id, work_order2.id])
      expect(results.pluck(:id)).to contain_exactly(problem1.id, problem2.id, problem3.id)
    end
  end

  describe '.where' do
    it 'finds problems matching conditions' do
      results = described_class.where(problem_type_id: problem_type1.id)
      expect(results.pluck(:id)).to contain_exactly(problem1.id)
    end
  end

  describe '.where_not' do
    it 'finds problems not matching conditions' do
      results = described_class.where_not(problem_type_id: problem_type1.id)
      expect(results.pluck(:id)).to contain_exactly(problem2.id)
    end
  end

  describe '.order' do
    it 'orders problems by specified field' do
      results = described_class.order(:created_at)
      expect(results.first).to eq(problem1)
    end
  end

  describe '.limit' do
    it 'limits number of results' do
      results = described_class.limit(1)
      expect(results.count).to eq(1)
    end
  end

  describe '.offset' do
    it 'offsets results by specified count' do
      results = described_class.order(:id).offset(1)
      expect(results.first.id).to be > problem1.id
    end
  end

  describe '.count' do
    it 'returns total count of problems' do
      expect(described_class.count).to eq(2)
    end
  end

  describe '.where_count' do
    it 'counts problems matching conditions' do
      count = described_class.where_count(problem_type_id: problem_type1.id)
      expect(count).to eq(1)
    end
  end

  describe '.group_by_problem_type' do
    it 'groups problems by problem type' do
      results = described_class.group_by_problem_type
      expect(results[problem_type1.id]).to eq(1)
      expect(results[problem_type2.id]).to eq(1)
    end
  end

  describe '.group_by_work_order' do
    it 'groups problems by work order' do
      results = described_class.group_by_work_order
      expect(results[work_order.id]).to eq(2)
    end
  end

  describe '.created_between' do
    it 'finds problems created within date range' do
      start_date = 1.day.ago
      end_date = 1.day.from_now
      results = described_class.created_between(start_date, end_date)
      expect(results.pluck(:id)).to contain_exactly(problem1.id, problem2.id)
    end

    it 'returns empty array when no problems in range' do
      start_date = 1.year.ago
      end_date = 6.months.ago
      results = described_class.created_between(start_date, end_date)
      expect(results).to be_empty
    end
  end

  describe '.created_today' do
    it 'finds problems created today' do
      results = described_class.created_today
      expect(results.pluck(:id)).to contain_exactly(problem1.id, problem2.id)
    end
  end

  describe '.includes' do
    it 'eager loads associations' do
      results = described_class.includes([:work_order, :problem_type])
      expect(results.first.work_order).to eq(work_order)
      expect(results.first.problem_type).to eq(problem_type1)
    end
  end

  describe '.with_work_order' do
    it 'includes work order association' do
      results = described_class.with_work_order
      expect { results.first.work_order }.not_to raise_error
    end
  end

  describe '.with_problem_type' do
    it 'includes problem type association' do
      results = described_class.with_problem_type
      expect { results.first.problem_type }.not_to raise_error
    end
  end

  describe '.with_all_associations' do
    it 'includes all associations' do
      results = described_class.with_all_associations
      expect { results.first.work_order }.not_to raise_error
      expect { results.first.problem_type }.not_to raise_error
    end
  end

  describe '.exists?' do
    it 'returns true when problem exists' do
      expect(described_class.exists?(id: problem1.id)).to be true
    end

    it 'returns false when problem does not exist' do
      expect(described_class.exists?(id: 99999)).to be false
    end
  end

  describe '.exists_by_id?' do
    it 'returns true when problem exists' do
      expect(described_class.exists_by_id?(problem1.id)).to be true
    end

    it 'returns false when problem does not exist' do
      expect(described_class.exists_by_id?(99999)).to be false
    end
  end

  describe '.exists_for_work_order_and_problem_type?' do
    it 'returns true when combination exists' do
      expect(described_class.exists_for_work_order_and_problem_type?(work_order.id, problem_type1.id)).to be true
    end

    it 'returns false when combination does not exist' do
      expect(described_class.exists_for_work_order_and_problem_type?(work_order.id, 99999)).to be false
    end
  end

  describe '.create' do
    let(:work_order2) { create(:express_receipt_work_order) }
    let(:problem_type3) { create(:problem_type) }

    it 'creates new work order problem' do
      expect do
        described_class.create(work_order: work_order2, problem_type: problem_type3)
      end.to change(WorkOrderProblem, :count).by(1)
    end
  end

  describe '.create!' do
    let(:work_order2) { create(:express_receipt_work_order) }
    let(:problem_type3) { create(:problem_type) }

    it 'creates new work order problem' do
      expect do
        described_class.create!(work_order: work_order2, problem_type: problem_type3)
      end.to change(WorkOrderProblem, :count).by(1)
    end

    it 'raises error on validation failure' do
      expect do
        described_class.create!(work_order: work_order, problem_type: problem_type1)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe '.update_all' do
    it 'updates all records matching conditions' do
      described_class.update_all({ created_at: 1.day.ago }, { problem_type_id: problem_type1.id })
      problem1.reload
      expect(problem1.created_at.to_date).to eq(1.day.ago.to_date)
    end
  end

  describe '.delete_all' do
    it 'deletes all records matching conditions' do
      expect do
        described_class.delete_all(problem_type_id: problem_type1.id)
      end.to change(WorkOrderProblem, :count).by(-1)
    end
  end

  describe '.page' do
    let(:problem_type3) { create(:problem_type) }
    let!(:problem3) { create(:work_order_problem, work_order: work_order, problem_type: problem_type3) }

    it 'paginates results with default per_page' do
      results = described_class.page(1, 2)
      expect(results.count).to eq(2)
    end

    it 'returns second page of results' do
      results = described_class.page(2, 2)
      expect(results.count).to eq(1)
    end
  end

  describe '.select_fields' do
    it 'selects specific fields' do
      results = described_class.select_fields(%i[id work_order_id])
      expect(results.first.attributes.keys).to include('id', 'work_order_id')
    end
  end

  describe '.optimized_list' do
    it 'returns optimized query with associations' do
      results = described_class.optimized_list
      expect { results.first.work_order }.not_to raise_error
      expect { results.first.problem_type }.not_to raise_error
    end
  end

  describe '.safe_find' do
    it 'finds problem safely' do
      result = described_class.safe_find(problem1.id)
      expect(result).to eq(problem1)
    end

    it 'returns nil on not found' do
      result = described_class.safe_find(99999)
      expect(result).to be_nil
    end

    it 'handles exceptions gracefully' do
      allow(WorkOrderProblem).to receive(:find).and_raise(StandardError.new('Database error'))
      result = described_class.safe_find(problem1.id)
      expect(result).to be_nil
    end
  end
end
