# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkOrderProblemCommand do
  let(:admin_user) { create(:admin_user) }
  let(:work_order) { create(:express_receipt_work_order) }
  let(:problem_type) { create(:problem_type) }
  let(:valid_attributes) do
    {
      work_order_id: work_order.id,
      problem_type_id: problem_type.id,
      description: 'Test problem description',
      severity: 'medium',
      reported_by: 'Test Reporter',
      admin_user_id: admin_user.id
    }
  end

  describe '#initialize' do
    it 'initializes with valid attributes' do
      command = described_class.new(valid_attributes)
      expect(command.work_order_id).to eq(work_order.id)
      expect(command.problem_type_id).to eq(problem_type.id)
      expect(command.description).to eq('Test problem description')
      expect(command.severity).to eq('medium')
      expect(command.admin_user_id).to eq(admin_user.id)
    end

    it 'accepts optional attributes' do
      attributes = valid_attributes.merge(
        suggested_action: 'Fix the issue',
        impact_assessment: 'Low impact'
      )
      command = described_class.new(attributes)
      expect(command.suggested_action).to eq('Fix the issue')
      expect(command.impact_assessment).to eq('Low impact')
    end
  end

  describe '#call' do
    context 'with valid attributes' do
      it 'creates a work order problem successfully' do
        command = described_class.new(valid_attributes)
        result = command.call

        expect(result).to be_success
        expect(result.data).to be_a(WorkOrderProblem)
        expect(result.data.work_order).to eq(work_order)
        expect(result.data.problem_type).to eq(problem_type)
      end

      it 'returns success message' do
        command = described_class.new(valid_attributes)
        result = command.call

        expect(result.message).to include('successfully created')
      end
    end

    context 'with invalid work order' do
      before do
        valid_attributes[:work_order_id] = 99999
      end

      it 'returns failure with work order error' do
        command = described_class.new(valid_attributes)
        result = command.call

        expect(result).not_to be_success
        expect(result.errors.first).to include("Couldn't find WorkOrder")
      end
    end

    context 'with invalid problem type' do
      before do
        valid_attributes[:problem_type_id] = 99999
      end

      it 'returns failure with problem type error' do
        command = described_class.new(valid_attributes)
        result = command.call

        expect(result).not_to be_success
        expect(result.errors.first).to include("Couldn't find ProblemType")
      end
    end

    context 'when work order problem already exists' do
      before do
        # Create the same association first
        WorkOrderProblem.create!(
          work_order: work_order,
          problem_type: problem_type
        )
      end

      it 'returns failure with duplicate error' do
        command = described_class.new(valid_attributes)
        result = command.call

        expect(result).not_to be_success
        expect(result.errors.first).to include('已关联此问题类型')
      end
    end
  end

  describe 'CommandResult' do
    it 'returns success for successful creation' do
      result = described_class::CommandResult.new(success: true)
      expect(result).to be_success
      expect(result.message).to include('successfully created')
    end

    it 'returns failure message for failed creation' do
      result = described_class::CommandResult.new(success: false, errors: ['Error'])
      expect(result).not_to be_success
      expect(result.message).to include('failed')
    end

    it 'stores data and errors correctly' do
      work_order_problem = double('WorkOrderProblem')
      result = described_class::CommandResult.new(
        success: true,
        data: work_order_problem,
        errors: []
      )
      expect(result.data).to eq(work_order_problem)
      expect(result.errors).to be_empty
    end
  end
end