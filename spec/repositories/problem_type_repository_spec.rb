# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProblemTypeRepository, type: :repository do
  let!(:fee_type1) { create(:fee_type) }
  let!(:fee_type2) { create(:fee_type) }
  let!(:active_problem) { create(:problem_type, fee_type: fee_type1, active: true) }
  let!(:inactive_problem) { create(:problem_type, fee_type: fee_type1, active: false) }
  let!(:problem_type2) { create(:problem_type, fee_type: fee_type2, active: true) }

  describe '.find' do
    it 'returns problem type when found' do
      result = described_class.find(active_problem.id)
      expect(result).to eq(active_problem)
    end

    it 'returns nil when not found' do
      result = described_class.find(99_999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_id' do
    it 'returns problem type when found' do
      result = described_class.find_by_id(active_problem.id)
      expect(result).to eq(active_problem)
    end

    it 'returns nil when not found' do
      result = described_class.find_by_id(99_999)
      expect(result).to be_nil
    end
  end

  describe '.find_by_ids' do
    it 'returns problem types for given ids' do
      ids = [active_problem.id, problem_type2.id]
      result = described_class.find_by_ids(ids)
      expect(result.count).to eq(2)
      expect(result).to include(active_problem, problem_type2)
    end

    it 'returns empty relation when no ids match' do
      result = described_class.find_by_ids([99_999, 99_998])
      expect(result.count).to eq(0)
    end
  end

  # Status scopes
  describe '.active' do
    it 'returns only active problem types' do
      result = described_class.active
      expect(result).to include(active_problem, problem_type2)
      expect(result).not_to include(inactive_problem)
    end
  end

  describe '.inactive' do
    it 'returns only inactive problem types' do
      result = described_class.inactive
      expect(result).to include(inactive_problem)
      expect(result).not_to include(active_problem, problem_type2)
    end
  end

  # Fee type-based queries
  describe '.by_fee_type' do
    it 'returns problem types for specific fee type' do
      result = described_class.by_fee_type(fee_type1.id)
      expect(result.count).to eq(2)
      expect(result).to include(active_problem, inactive_problem)
      expect(result).not_to include(problem_type2)
    end

    it 'returns empty when no problem types for fee type' do
      result = described_class.by_fee_type(99_999)
      expect(result).to be_empty
    end
  end

  describe '.for_fee_type' do
    it 'returns problem types for specific fee type object' do
      result = described_class.for_fee_type(fee_type1)
      expect(result.count).to eq(2)
      expect(result).to include(active_problem, inactive_problem)
      expect(result).not_to include(problem_type2)
    end
  end

  describe '.for_fee_types' do
    it 'returns problem types for multiple fee types' do
      result = described_class.for_fee_types([fee_type1, fee_type2])
      expect(result.count).to eq(3)
      expect(result).to include(active_problem, inactive_problem, problem_type2)
    end
  end

  # Search functionality
  describe '.search_by_title' do
    it 'returns problem types matching title pattern' do
      # Update one problem type to have a specific title
      active_problem.update!(title: '发票不合规问题')
      result = described_class.search_by_title('发票')
      expect(result).to include(active_problem)
    end

    it 'returns empty when no title matches' do
      result = described_class.search_by_title('不存在的关键词')
      expect(result).to be_empty
    end
  end

  describe '.search_by_issue_code' do
    it 'returns problem types matching issue code pattern' do
      result = described_class.search_by_issue_code(active_problem.issue_code[0..2])
      expect(result).to include(active_problem)
    end

    it 'returns empty when no issue code matches' do
      result = described_class.search_by_issue_code('XXX')
      expect(result).to be_empty
    end
  end

  # Count operations
  describe '.active_count' do
    it 'returns count of active problem types' do
      result = described_class.active_count
      expect(result).to eq(2)
    end
  end

  describe '.inactive_count' do
    it 'returns count of inactive problem types' do
      result = described_class.inactive_count
      expect(result).to eq(1)
    end
  end

  describe '.count_by_fee_type' do
    it 'returns counts grouped by fee type' do
      result = described_class.count_by_fee_type
      expect(result[fee_type1.id]).to eq(2)
      expect(result[fee_type2.id]).to eq(1)
    end
  end

  # Pagination
  describe '.page' do
    it 'returns paginated results' do
      result = described_class.page(1, 2)
      expect(result.count).to eq(2)
    end
  end

  # Existence checks
  describe '.exists?' do
    it 'returns true when problem type exists' do
      result = described_class.exists?(id: active_problem.id)
      expect(result).to be true
    end

    it 'returns false when problem type does not exist' do
      result = described_class.exists?(id: 99_999)
      expect(result).to be false
    end
  end

  describe '.exists_by_issue_code?' do
    it 'returns true when issue code exists for fee type' do
      result = described_class.exists_by_issue_code?(active_problem.issue_code, fee_type1.id)
      expect(result).to be true
    end

    it 'returns false when issue code does not exist' do
      result = described_class.exists_by_issue_code?('NON-EXISTENT', fee_type1.id)
      expect(result).to be false
    end
  end

  # Performance optimizations
  describe '.select_fields' do
    it 'returns only selected fields' do
      result = described_class.select_fields(%i[id issue_code])
      expect(result.first).to have_attributes(id: active_problem.id, issue_code: active_problem.issue_code)
      expect { result.first.title }.to raise_error(ActiveModel::MissingAttributeError)
    end
  end

  describe '.optimized_list' do
    it 'includes fee type association' do
      result = described_class.optimized_list
      expect(result).to respond_to(:each)
      expect(result.first).to respond_to(:fee_type)
    end
  end

  # Error handling
  describe '.safe_find' do
    it 'returns problem type when found' do
      result = described_class.safe_find(active_problem.id)
      expect(result).to eq(active_problem)
    end

    it 'returns nil when not found without logging error' do
      expect(Rails.logger).not_to receive(:error)
      result = described_class.safe_find(99_999)
      expect(result).to be_nil
    end

    it 'returns nil when exception occurs' do
      allow(ProblemType).to receive(:find).and_raise(StandardError, 'Database connection failed')
      result = described_class.safe_find(99_999)
      expect(result).to be_nil
    end
  end

  describe '.safe_find_by_issue_code' do
    it 'returns problem type when found' do
      result = described_class.safe_find_by_issue_code(active_problem.issue_code, fee_type1.id)
      expect(result).to eq(active_problem)
    end

    it 'returns nil when not found without logging error' do
      expect(Rails.logger).not_to receive(:error)
      result = described_class.safe_find_by_issue_code('NON-EXISTENT', fee_type1.id)
      expect(result).to be_nil
    end

    it 'returns nil when exception occurs' do
      allow(ProblemType).to receive(:find_by).and_raise(StandardError, 'Database connection failed')
      result = described_class.safe_find_by_issue_code(active_problem.issue_code, fee_type1.id)
      expect(result).to be_nil
    end
  end

  # Complex queries (simplified for SQLite compatibility)
  describe '.problem_type_summary' do
    it 'returns problem type summary with fee type details' do
      # Test that the method runs without error
      expect { described_class.problem_type_summary }.not_to raise_error
    end
  end

  describe '.active_by_fee_type' do
    it 'returns active problem types with fee type details' do
      # Test that the method runs without error and returns expected structure
      result = described_class.active_by_fee_type
      expect(result).to respond_to(:find)
      expect(result.first).to respond_to(:fee_type_name)
    end
  end

  describe '.problem_types_with_work_order_count' do
    it 'returns problem types with work order counts' do
      # Test that the method runs without error and returns expected structure
      result = described_class.problem_types_with_work_order_count
      expect(result).to respond_to(:find)
      expect(result.first).to respond_to(:work_order_count)
    end
  end

  describe 'method chaining' do
    it 'allows method chaining for complex queries' do
      result = described_class
               .active
               .by_fee_type(fee_type1.id)
               .order(:issue_code)
               .limit(1)

      expect(result.count).to eq(1)
      expect(result.first).to eq(active_problem)
    end
  end

  describe 'performance optimizations' do
    it 'uses optimized list for dashboard queries' do
      result = described_class.optimized_list
      expect(result).to respond_to(:each)
    end
  end
end
