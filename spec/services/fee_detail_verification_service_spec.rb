# spec/services/fee_detail_verification_service_spec.rb
require 'rails_helper'

RSpec.describe FeeDetailVerificationService do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement, status: 'processing') }
  let(:fee_detail) do
    create(:fee_detail, document_number: reimbursement.invoice_number, verification_status: 'pending')
  end
  let(:service) { described_class.new(admin_user) }

  describe '#initialize' do
    it 'sets Current.admin_user' do
      expect(Current).to receive(:admin_user=).with(admin_user)
      described_class.new(admin_user)
    end
  end

  describe '#update_verification_status' do
    context 'with valid status' do
      it 'updates fee detail status directly' do
        expect(fee_detail).to receive(:update).with(hash_including(verification_status: 'verified')).and_return(true)
        expect(service.update_verification_status(fee_detail, 'verified')).to be true
      end

      it 'updates fee detail to problematic' do
        expect(fee_detail).to receive(:update).with(hash_including(verification_status: 'problematic')).and_return(true)
        expect(service.update_verification_status(fee_detail, 'problematic')).to be true
      end

      it 'includes comment as notes when provided' do
        expect(fee_detail).to receive(:update).with(hash_including(verification_status: 'verified',
                                                                   notes: '测试备注')).and_return(true)
        expect(service.update_verification_status(fee_detail, 'verified', '测试备注')).to be true
      end

      it 'calls update_status_based_on_fee_details! on reimbursement after successful update' do
        allow(fee_detail).to receive(:update).and_return(true)
        allow(fee_detail).to receive(:reimbursement).and_return(reimbursement) # Ensure reimbursement is available
        expect(reimbursement).to receive(:update_status_based_on_fee_details!)
        service.update_verification_status(fee_detail, 'verified')
      end
    end

    context 'with invalid status' do
      it 'returns false' do
        expect(service.update_verification_status(fee_detail, 'invalid_status')).to be false
      end

      it 'adds error to fee detail' do
        service.update_verification_status(fee_detail, 'invalid_status')
        expect(fee_detail.errors[:verification_status]).to include(a_string_matching(/无效的验证状态/))
      end
    end

    context 'when reimbursement is closed' do
      before do
        allow(reimbursement).to receive(:closed?).and_return(true)
        allow(fee_detail).to receive(:reimbursement).and_return(reimbursement)
      end

      it 'returns false' do
        expect(service.update_verification_status(fee_detail, 'verified')).to be false
      end

      it 'adds error to fee detail' do
        service.update_verification_status(fee_detail, 'verified')
        expect(fee_detail.errors[:base]).to include(a_string_matching(/报销单已关闭/))
      end
    end
  end

  describe '#batch_update_verification_status' do
    let(:fee_detail1) { create(:fee_detail, verification_status: 'pending') }
    let(:fee_detail2) { create(:fee_detail, verification_status: 'pending') }
    let(:fee_details) { [fee_detail1, fee_detail2] }

    it 'updates all fee details' do
      expect(service).to receive(:update_verification_status).with(fee_detail1, 'verified', nil).and_return(true)
      expect(service).to receive(:update_verification_status).with(fee_detail2, 'verified', nil).and_return(true)

      expect(service.batch_update_verification_status(fee_details, 'verified')).to be true
    end

    it 'returns false if any update fails' do
      expect(service).to receive(:update_verification_status).with(fee_detail1, 'verified', nil).and_return(true)
      expect(service).to receive(:update_verification_status).with(fee_detail2, 'verified', nil).and_return(false)

      expect(service.batch_update_verification_status(fee_details, 'verified')).to be false
    end

    it 'returns false with invalid status' do
      expect(service.batch_update_verification_status(fee_details, 'invalid_status')).to be false
    end

    it 'passes comment to update_verification_status' do
      expect(service).to receive(:update_verification_status).with(fee_detail1, 'verified', '测试批量验证').and_return(true)
      expect(service).to receive(:update_verification_status).with(fee_detail2, 'verified', '测试批量验证').and_return(true)

      service.batch_update_verification_status(fee_details, 'verified', '测试批量验证')
    end
  end
end
