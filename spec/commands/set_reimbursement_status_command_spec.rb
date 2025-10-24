# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/commands/set_reimbursement_status_command'

RSpec.describe Commands::SetReimbursementStatusCommand, type: :command do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement, status: 'pending') }
  let(:command) { described_class.new }

  describe '#initialize' do
    it 'initializes with default values' do
      cmd = described_class.new
      expect(cmd.reimbursement_id).to be_nil
      expect(cmd.status).to be_nil
      expect(cmd.current_user).to be_nil
    end

    it 'initializes with provided values' do
      cmd = described_class.new(
        reimbursement_id: reimbursement.id,
        status: 'processing',
        current_user: admin_user
      )
      expect(cmd.reimbursement_id).to eq(reimbursement.id)
      expect(cmd.status).to eq('processing')
      expect(cmd.current_user).to eq(admin_user)
    end
  end

  describe '#call' do
    context 'with valid inputs' do
      let(:valid_command) do
        described_class.new(
          reimbursement_id: reimbursement.id,
          status: 'processing',
          current_user: admin_user
        )
      end

      it 'successfully sets reimbursement status' do
        result = valid_command.call

        expect(result.success?).to be true
        expect(result.data).to be_a(Reimbursement)
        expect(result.message).to include('Successfully set reimbursement status')
      end

      it 'updates reimbursement status' do
        result = valid_command.call
        updated_reimbursement = result.data

        expect(updated_reimbursement.status).to eq('processing')
      end
    end

    context 'with invalid inputs' do
      it 'fails when reimbursement_id is nil' do
        command = described_class.new(
          reimbursement_id: nil,
          status: 'processing',
          current_user: admin_user
        )

        result = command.call

        expect(result.failure?).to be true
        expect(result.errors).to include('Reimbursement不能为空')
      end

      it 'fails when status is nil' do
        command = described_class.new(
          reimbursement_id: reimbursement.id,
          status: nil,
          current_user: admin_user
        )

        result = command.call

        expect(result.failure?).to be true
        expect(result.errors).to include('Status不能为空')
      end

      it 'fails when current_user is nil' do
        command = described_class.new(
          reimbursement_id: reimbursement.id,
          status: 'processing',
          current_user: nil
        )

        result = command.call

        expect(result.failure?).to be true
        expect(result.errors).to include('Current user不能为空')
      end

      it 'fails when reimbursement does not exist' do
        command = described_class.new(
          reimbursement_id: 99_999,
          status: 'processing',
          current_user: admin_user
        )

        result = command.call

        expect(result.failure?).to be true
        expect(result.errors).to include('Reimbursement not found')
      end
    end

    context 'when status service fails' do
      before do
        allow_any_instance_of(ReimbursementStatusOverrideService).to receive(:set_status).and_return(
          ReimbursementStatusOverrideService::Result.new(
            success: false,
            message: 'Status change failed'
          )
        )
      end

      it 'returns failure result' do
        command = described_class.new(
          reimbursement_id: reimbursement.id,
          status: 'processing',
          current_user: admin_user
        )

        result = command.call

        expect(result.failure?).to be true
        expect(result.errors).to include('Status change failed')
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow_any_instance_of(ReimbursementStatusOverrideService).to receive(:set_status).and_raise(StandardError.new('Database error'))
      end

      it 'returns failure result with error message' do
        command = described_class.new(
          reimbursement_id: reimbursement.id,
          status: 'processing',
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

    it 'validates presence of status' do
      command.status = nil
      expect(command.valid?).to be false
      expect(command.errors[:status]).to include('不能为空')
    end

    it 'validates presence of current_user' do
      command.current_user = nil
      expect(command.valid?).to be false
      expect(command.errors[:current_user]).to include('不能为空')
    end
  end
end
