# spec/services/fee_detail_verification_service_spec.rb
require 'rails_helper'

RSpec.describe FeeDetailVerificationService do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement, status: 'processing') }
  let(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number, verification_status: 'pending') }
  let(:service) { described_class.new(admin_user) }
  
  describe '#initialize' do
    it 'sets Current.admin_user' do
      expect(Current).to receive(:admin_user=).with(admin_user)
      described_class.new(admin_user)
    end
  end
  
  describe '#update_verification_status' do
    context 'with valid status' do
      it 'updates fee detail to verified' do
        expect(fee_detail).to receive(:mark_as_verified).with(admin_user, nil).and_return(true)
        expect(service.update_verification_status(fee_detail, 'verified')).to be true
      end
      
      it 'updates fee detail to problematic' do
        expect(fee_detail).to receive(:mark_as_problematic).with(admin_user, nil).and_return(true)
        expect(service.update_verification_status(fee_detail, 'problematic')).to be true
      end
      
      it 'passes comment to mark_as_verified' do
        expect(fee_detail).to receive(:mark_as_verified).with(admin_user, '测试验证意见').and_return(true)
        service.update_verification_status(fee_detail, 'verified', '测试验证意见')
      end
      
      it 'updates associated fee detail selections' do
        selection = create(:fee_detail_selection, fee_detail: fee_detail, verification_status: 'pending')
        
        allow(fee_detail).to receive(:mark_as_verified).and_return(true)
        allow(fee_detail).to receive(:fee_detail_selections).and_return([selection])
        
        expect(selection).to receive(:update).with(
          hash_including(
            verification_status: 'verified',
            verification_comment: nil,
            verified_by: admin_user.id
          )
        )
        
        service.update_verification_status(fee_detail, 'verified')
      end

      it 'calls update_status_based_on_fee_details! on reimbursement after successful update' do
        allow(fee_detail).to receive(:mark_as_verified).and_return(true)
        allow(fee_detail).to receive(:fee_detail_selections).and_return([]) # Stub to avoid testing selections update here
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