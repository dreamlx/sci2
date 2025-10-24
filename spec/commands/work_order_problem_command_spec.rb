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
        expect(result.data.description).to eq('Test problem description')
        expect(result.data.severity).to eq('medium')
        expect(result.data.admin_user).to eq(admin_user)
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
        expect(result.errors).to include('Work order not found')
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
        expect(result.errors).to include('Problem type not found')
      end
    end

    context 'with missing description' do
      before do
        valid_attributes[:description] = ''
      end

      it 'returns failure with description error' do
        command = described_class.new(valid_attributes)
        result = command.call

        expect(result).not_to be_success
        expect(result.errors).to include('Description is required')
      end
    end

    context 'with invalid severity' do
      before do
        valid_attributes[:severity] = 'invalid'
      end

      it 'returns failure with severity error' do
        command = described_class.new(valid_attributes)
        result = command.call

        expect(result).not_to be_success
        expect(result.errors).to include('Severity must be valid')
      end
    end

    context 'with invalid admin user' do
      before do
        valid_attributes[:admin_user_id] = 99999
      end

      it 'returns failure with admin user error' do
        command = described_class.new(valid_attributes)
        result = command.call

        expect(result).not_to be_success
        expect(result.errors).to include('Admin user not found')
      end
    end

    context 'when work order is closed' do
      before do
        work_order.update(status: 'closed')
      end

      it 'returns failure with closed status error' do
        command = described_class.new(valid_attributes)
        result = command.call

        expect(result).not_to be_success
        expect(result.errors).to include('Cannot add problems to closed work orders')
      end
    end

    context 'when database save fails' do
      before do
        allow_any_instance_of(WorkOrderProblem).to receive(:save).and_return(false)
        allow_any_instance_of(WorkOrderProblem).to receive_message_chain(:errors, :full_messages).and_return(['Database error'])
      end

      it 'returns failure with database error' do
        command = described_class.new(valid_attributes)
        result = command.call

        expect(result).not_to be_success
        expect(result.errors).to include('Database error')
      end
    end
  end

  describe '#valid_severities' do
    it 'returns array of valid severities' do
      severities = described_class.new(valid_attributes).send(:valid_severities)
      expect(severities).to include('low', 'medium', 'high', 'critical')
    end
  end

  describe '#validate_work_order' do
    let(:command) { described_class.new(valid_attributes) }

    it 'returns true for valid work order' do
      expect(command.send(:validate_work_order)).to be true
    end

    it 'returns false for non-existent work order' do
      command.work_order_id = 99999
      expect(command.send(:validate_work_order)).to be false
    end

    it 'returns false for nil work order id' do
      command.work_order_id = nil
      expect(command.send(:validate_work_order)).to be false
    end
  end

  describe '#validate_problem_type' do
    let(:command) { described_class.new(valid_attributes) }

    it 'returns true for valid problem type' do
      expect(command.send(:validate_problem_type)).to be true
    end

    it 'returns false for non-existent problem type' do
      command.problem_type_id = 99999
      expect(command.send(:validate_problem_type)).to be false
    end

    it 'returns false for nil problem type id' do
      command.problem_type_id = nil
      expect(command.send(:validate_problem_type)).to be false
    end
  end

  describe '#validate_admin_user' do
    let(:command) { described_class.new(valid_attributes) }

    it 'returns true for valid admin user' do
      expect(command.send(:validate_admin_user)).to be true
    end

    it 'returns false for non-existent admin user' do
      command.admin_user_id = 99999
      expect(command.send(:validate_admin_user)).to be false
    end

    it 'returns false for nil admin user id' do
      command.admin_user_id = nil
      expect(command.send(:validate_admin_user)).to be false
    end
  end

  describe '#validate_description' do
    let(:command) { described_class.new(valid_attributes) }

    it 'returns true for valid description' do
      expect(command.send(:validate_description)).to be true
    end

    it 'returns false for empty description' do
      command.description = ''
      expect(command.send(:validate_description)).to be false
    end

    it 'returns false for nil description' do
      command.description = nil
      expect(command.send(:validate_description)).to be false
    end

    it 'returns false for description that is too short' do
      command.description = 'A'
      expect(command.send(:validate_description)).to be false
    end
  end

  describe '#validate_severity' do
    let(:command) { described_class.new(valid_attributes) }

    it 'returns true for valid severities' do
      %w[low medium high critical].each do |severity|
        command.severity = severity
        expect(command.send(:validate_severity)).to be true
      end
    end

    it 'returns false for invalid severity' do
      command.severity = 'invalid'
      expect(command.send(:validate_severity)).to be false
    end

    it 'returns false for nil severity' do
      command.severity = nil
      expect(command.send(:validate_severity)).to be false
    end
  end

  describe '#validate_work_order_status' do
    let(:command) { described_class.new(valid_attributes) }

    it 'returns true for open work order' do
      expect(command.send(:validate_work_order_status)).to be true
    end

    it 'returns false for closed work order' do
      work_order.update(status: 'closed')
      expect(command.send(:validate_work_order_status)).to be false
    end

    it 'returns false for cancelled work order' do
      work_order.update(status: 'cancelled')
      expect(command.send(:validate_work_order_status)).to be false
    end
  end

  describe 'error handling' do
    it 'handles validation errors gracefully' do
      command = described_class.new({})
      result = command.call

      expect(result).not_to be_success
      expect(result.errors).to be_present
      expect(result.message).to include('failed')
    end

    it 'handles unexpected errors gracefully' do
      command = described_class.new(valid_attributes)
      allow(WorkOrderProblem).to receive(:new).and_raise(StandardError, 'Unexpected error')

      result = command.call

      expect(result).not_to be_success
      expect(result.errors).to include('Unexpected error')
    end
  end

  describe 'integration with work order status' do
    it 'updates work order status when critical problem is added' do
      valid_attributes[:severity] = 'critical'
      command = described_class.new(valid_attributes)
      result = command.call

      expect(result).to be_success
      expect(work_order.reload.status).to eq('requires_attention')
    end

    it 'does not change work order status for low severity problems' do
      valid_attributes[:severity] = 'low'
      original_status = work_order.status
      command = described_class.new(valid_attributes)
      result = command.call

      expect(result).to be_success
      expect(work_order.reload.status).to eq(original_status)
    end
  end
end