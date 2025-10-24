# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/commands/assign_reimbursement_command'

RSpec.describe Commands::AssignReimbursementCommand, type: :command do
  let(:admin_user) { create(:admin_user) }
  let(:assignee) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement, status: 'pending') }
  let(:command) { described_class.new }

  describe '#initialize' do
    it 'initializes with default values' do
      cmd = described_class.new
      expect(cmd.reimbursement_id).to be_nil
      expect(cmd.assignee_id).to be_nil
      expect(cmd.notes).to be_nil
      expect(cmd.current_user).to be_nil
    end

    it 'initializes with provided values' do
      cmd = described_class.new(
        reimbursement_id: reimbursement.id,
        assignee_id: assignee.id,
        notes: 'Test notes',
        current_user: admin_user
      )
      expect(cmd.reimbursement_id).to eq(reimbursement.id)
      expect(cmd.assignee_id).to eq(assignee.id)
      expect(cmd.notes).to eq('Test notes')
      expect(cmd.current_user).to eq(admin_user)
    end
  end

  describe '#call' do
    context 'with valid inputs' do
      let(:valid_command) do
        described_class.new(
          reimbursement_id: reimbursement.id,
          assignee_id: assignee.id,
          notes: 'Assignment notes',
          current_user: admin_user
        )
      end

      it 'successfully assigns reimbursement' do
        result = valid_command.call

        expect(result.success?).to be true
        expect(result.data).to be_a(ReimbursementAssignment)
        expect(result.message).to include('Successfully assigned')
      end

      it 'creates assignment with correct attributes' do
        result = valid_command.call
        assignment = result.data

        expect(assignment.reimbursement).to eq(reimbursement)
        expect(assignment.assignee).to eq(assignee)
        expect(assignment.notes).to eq('Assignment notes')
        expect(assignment.assigner).to eq(admin_user)
      end
    end

    context 'with invalid inputs' do
      it 'fails when reimbursement_id is nil' do
        command = described_class.new(
          reimbursement_id: nil,
          assignee_id: assignee.id,
          current_user: admin_user
        )

        result = command.call

        expect(result.failure?).to be true
        expect(result.errors).to include('Reimbursement不能为空')
      end

      it 'fails when assignee_id is nil' do
        command = described_class.new(
          reimbursement_id: reimbursement.id,
          assignee_id: nil,
          current_user: admin_user
        )

        result = command.call

        expect(result.failure?).to be true
        expect(result.errors).to include('Assignee不能为空')
      end

      it 'fails when current_user is nil' do
        command = described_class.new(
          reimbursement_id: reimbursement.id,
          assignee_id: assignee.id,
          current_user: nil
        )

        result = command.call

        expect(result.failure?).to be true
        expect(result.errors).to include('Current user不能为空')
      end

      it 'fails when reimbursement does not exist' do
        command = described_class.new(
          reimbursement_id: 99_999,
          assignee_id: assignee.id,
          current_user: admin_user
        )

        result = command.call

        expect(result.failure?).to be true
        expect(result.errors).to include('Reimbursement not found')
      end

      it 'fails when assignee does not exist' do
        command = described_class.new(
          reimbursement_id: reimbursement.id,
          assignee_id: 99_999,
          current_user: admin_user
        )

        result = command.call

        expect(result.failure?).to be true
        expect(result.errors).to include('Assignee not found')
      end
    end

    context 'when assignment service fails' do
      before do
        allow_any_instance_of(ReimbursementAssignmentService).to receive(:assign).and_return(nil)
      end

      it 'returns failure result' do
        command = described_class.new(
          reimbursement_id: reimbursement.id,
          assignee_id: assignee.id,
          current_user: admin_user
        )

        result = command.call

        expect(result.failure?).to be true
        expect(result.errors).to include('Assignment failed')
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow_any_instance_of(ReimbursementAssignmentService).to receive(:assign).and_raise(StandardError.new('Database error'))
      end

      it 'returns failure result with error message' do
        command = described_class.new(
          reimbursement_id: reimbursement.id,
          assignee_id: assignee.id,
          current_user: admin_user
        )

        result = command.call

        expect(result.failure?).to be true
        expect(result.errors).to include('Unexpected error: Database error')
      end
    end
  end

  describe 'ActiveModel validations' do
    let(:command) { described_class.new }

    it 'validates presence of reimbursement_id' do
      command.reimbursement_id = nil
      expect(command.valid?).to be false
      expect(command.errors[:reimbursement_id]).to include('不能为空')
    end

    it 'validates presence of assignee_id' do
      command.assignee_id = nil
      expect(command.valid?).to be false
      expect(command.errors[:assignee_id]).to include('不能为空')
    end

    it 'validates presence of current_user' do
      command.current_user = nil
      expect(command.valid?).to be false
      expect(command.errors[:current_user]).to include('不能为空')
    end
  end
end
