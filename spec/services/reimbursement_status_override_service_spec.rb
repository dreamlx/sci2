require 'rails_helper'

RSpec.describe ReimbursementStatusOverrideService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement, status: 'pending') }
  let(:service) { described_class.new(admin_user) }

  describe 'Result class' do
    describe '#success?' do
      it 'returns true when success is true' do
        result = described_class::Result.new(success: true, message: 'Success')
        expect(result.success?).to be true
      end

      it 'returns false when success is false' do
        result = described_class::Result.new(success: false, message: 'Failure')
        expect(result.success?).to be false
      end
    end

    describe '#failure?' do
      it 'returns true when success is false' do
        result = described_class::Result.new(success: false, message: 'Failure')
        expect(result.failure?).to be true
      end

      it 'returns false when success is true' do
        result = described_class::Result.new(success: true, message: 'Success')
        expect(result.failure?).to be false
      end
    end
  end

  describe '#set_status' do
    context 'with valid inputs' do
      it 'successfully updates reimbursement status' do
        result = service.set_status(reimbursement, 'processing')

        expect(result.success?).to be true
        expect(result.message).to include('Successfully updated')
        expect(result.reimbursement).to eq(reimbursement)
        expect(reimbursement.reload.status).to eq('processing')
        expect(reimbursement.manual_override?).to be true
        expect(reimbursement.manual_override_at).to be_present
      end

      it 'sets manual override flag and timestamp' do
        expect {
          service.set_status(reimbursement, 'closed')
        }.to change(reimbursement, :manual_override).from(false).to(true)

        expect(reimbursement.reload.manual_override_at).to be_within(1.second).of(Time.current)
      end

      it 'logs the status change operation' do
        expect(Rails.logger).to receive(:info).with(
          match(/Manual status change by #{admin_user.email}: #{reimbursement.invoice_number} -> processing/)
        )

        service.set_status(reimbursement, 'processing')
      end

      it 'handles status change from closed to processing' do
        reimbursement.update!(status: 'closed', manual_override: false)

        result = service.set_status(reimbursement, 'processing')

        expect(result.success?).to be true
        expect(reimbursement.reload.status).to eq('processing')
        expect(reimbursement.manual_override?).to be true
      end
    end

    context 'with invalid inputs' do
      it 'fails when reimbursement is not a Reimbursement object' do
        result = service.set_status('not_a_reimbursement', 'processing')

        expect(result.failure?).to be true
        expect(result.message).to include('Invalid reimbursement object')
      end

      it 'fails when status is nil' do
        result = service.set_status(reimbursement, nil)

        expect(result.failure?).to be true
        expect(result.message).to include('Invalid status provided')
      end

      it 'fails when status is empty string' do
        result = service.set_status(reimbursement, '')

        expect(result.failure?).to be true
        expect(result.message).to include('Invalid status provided')
      end

      it 'fails when status is not in valid statuses list' do
        result = service.set_status(reimbursement, 'invalid_status')

        expect(result.failure?).to be true
        expect(result.message).to include("Invalid status 'invalid_status'")
        expect(result.message).to include('Valid statuses are')
      end
    end

    context 'when status is not changing' do
      it 'returns failure with appropriate message' do
        result = service.set_status(reimbursement, 'pending')

        expect(result.failure?).to be true
        expect(result.message).to include("Status is already set to 'pending'")
        expect(result.message).to include('No change needed')
      end

      it 'does not modify manual override fields' do
        original_manual_override = reimbursement.manual_override
        original_override_at = reimbursement.manual_override_at

        service.set_status(reimbursement, 'pending')

        expect(reimbursement.reload.manual_override).to eq(original_manual_override)
        expect(reimbursement.manual_override_at).to eq(original_override_at)
      end
    end

    context 'when database validation fails' do
      before do
        allow(reimbursement).to receive(:manual_status_change!).and_raise(
          ActiveRecord::RecordInvalid.new(reimbursement)
        )
        allow(reimbursement.errors).to receive(:full_messages).and_return(['Validation error'])
      end

      it 'returns failure with validation errors' do
        result = service.set_status(reimbursement, 'processing')

        expect(result.failure?).to be true
        expect(result.message).to include('Failed to update status')
        expect(result.errors).to include('Validation error')
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow(reimbursement).to receive(:manual_status_change!).and_raise(
          StandardError.new('Unexpected error')
        )
      end

      it 'returns failure with error message' do
        result = service.set_status(reimbursement, 'processing')

        expect(result.failure?).to be true
        expect(result.message).to include('Unexpected error occurred')
        expect(result.errors).to include('Unexpected error')
      end
    end

    context 'without current user' do
      let(:service_without_user) { described_class.new }

      it 'logs operation as system user' do
        expect(Rails.logger).to receive(:info).with(
          match(/Manual status change by system: #{reimbursement.invoice_number} -> processing/)
        )

        service_without_user.set_status(reimbursement, 'processing')
      end
    end
  end

  describe '#reset_override' do
    context 'with valid inputs and existing override' do
      before do
        reimbursement.update!(manual_override: true, manual_override_at: 1.hour.ago)
      end

      it 'successfully resets manual override' do
        result = service.reset_override(reimbursement)

        expect(result.success?).to be true
        expect(result.message).to include('Successfully reset manual override')
        expect(result.reimbursement).to eq(reimbursement)
        expect(reimbursement.reload.manual_override?).to be false
        expect(reimbursement.manual_override_at).to be_nil
      end

      it 'logs the reset operation' do
        expect(Rails.logger).to receive(:info).with(
          match(/Manual override reset by #{admin_user.email}:.*at #{Time.current.year}/)
        )

        service.reset_override(reimbursement)
      end
    end

    context 'with valid inputs but no existing override' do
      it 'returns failure with appropriate message' do
        result = service.reset_override(reimbursement)

        expect(result.failure?).to be true
        expect(result.message).to include('No manual override exists')
        expect(result.message).to include(reimbursement.invoice_number)
      end

      it 'does not modify the reimbursement' do
        original_attributes = reimbursement.attributes

        service.reset_override(reimbursement)

        expect(reimbursement.reload.attributes).to eq(original_attributes)
      end
    end

    context 'with invalid inputs' do
      it 'fails when reimbursement is not a Reimbursement object' do
        result = service.reset_override('not_a_reimbursement')

        expect(result.failure?).to be true
        expect(result.message).to include('Invalid reimbursement object')
      end
    end

    context 'when database validation fails' do
      before do
        reimbursement.update!(manual_override: true)
        allow(reimbursement).to receive(:reset_manual_override!).and_raise(
          ActiveRecord::RecordInvalid.new(reimbursement)
        )
        allow(reimbursement.errors).to receive(:full_messages).and_return(['Reset validation error'])
      end

      it 'returns failure with validation errors' do
        result = service.reset_override(reimbursement)

        expect(result.failure?).to be true
        expect(result.message).to include('Failed to reset override')
        expect(result.errors).to include('Reset validation error')
      end
    end

    context 'when unexpected error occurs' do
      before do
        reimbursement.update!(manual_override: true)
        allow(reimbursement).to receive(:reset_manual_override!).and_raise(
          StandardError.new('Unexpected reset error')
        )
      end

      it 'returns failure with error message' do
        result = service.reset_override(reimbursement)

        expect(result.failure?).to be true
        expect(result.message).to include('Unexpected error occurred')
        expect(result.errors).to include('Unexpected reset error')
      end
    end

    context 'without current user' do
      let(:service_without_user) { described_class.new }

      before do
        reimbursement.update!(manual_override: true)
      end

      it 'logs operation as system user' do
        expect(Rails.logger).to receive(:info).with(
          match(/Manual override reset by system:/)
        )

        service_without_user.reset_override(reimbursement)
      end
    end
  end

  describe 'integration scenarios' do
    it 'allows setting status and then resetting override' do
      # Set status with override
      set_result = service.set_status(reimbursement, 'processing')
      expect(set_result.success?).to be true
      expect(reimbursement.reload.manual_override?).to be true

      # Reset the override
      reset_result = service.reset_override(reimbursement)
      expect(reset_result.success?).to be true
      expect(reimbursement.reload.manual_override?).to be false

      # Status should remain changed, but override flag is reset
      expect(reimbursement.status).to eq('processing')
    end

    it 'handles multiple status changes correctly' do
      # First change
      result1 = service.set_status(reimbursement, 'processing')
      expect(result1.success?).to be true

      # Second change (should work even though manual_override is already true)
      result2 = service.set_status(reimbursement, 'closed')
      expect(result2.success?).to be true
      expect(reimbursement.reload.status).to eq('closed')
      expect(reimbursement.manual_override?).to be true
    end

    it 'respects status constants from the model' do
      Reimbursement::STATUSES.each do |valid_status|
        next if valid_status == reimbursement.status # Skip current status

        result = service.set_status(reimbursement, valid_status)
        expect(result.success?).to be true
        expect(result.message).not_to include("Failed")
        expect(reimbursement.reload.status).to eq(valid_status)
      end
    end
  end
end