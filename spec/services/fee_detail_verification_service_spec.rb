require 'rails_helper'

RSpec.describe FeeDetailVerificationService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement, status: 'processing') }
  let(:work_order) { create(:audit_work_order, reimbursement: reimbursement, status: 'auditing') }
  let(:service) { FeeDetailVerificationService.new(admin_user) }

  describe '#update_verification_status' do
    let(:fee_detail) { create(:fee_detail, reimbursement: reimbursement, verification_status: 'pending') }

    it 'updates the verification status of a fee detail' do
      expect(service.update_verification_status(fee_detail, 'approved', '审核通过')).to be_truthy
      expect(fee_detail.reload.verification_status).to eq('approved')
    end
  end

  describe '#verify_fee_details' do
    let(:fee_detail1) { create(:fee_detail, reimbursement: reimbursement, verification_status: 'pending') }
    let(:fee_detail2) { create(:fee_detail, reimbursement: reimbursement, verification_status: 'pending') }
    let(:fee_detail3) { create(:fee_detail, reimbursement: reimbursement, verification_status: 'rejected') }

    it 'verifies multiple fee details' do
      result = service.verify_fee_details([fee_detail1.id, fee_detail2.id, fee_detail3.id], 'approved', '批量审核通过')
      expect(result.size).to eq(3)
      expect(fee_detail1.reload.verification_status).to eq('approved')
      expect(fee_detail2.reload.verification_status).to eq('approved')
      expect(fee_detail3.reload.verification_status).to eq('approved')
    end
  end

  describe '#verify_fee_detail_in_work_order' do
    let(:fee_detail) { create(:fee_detail, reimbursement: reimbursement, verification_status: 'pending') }

    it 'verifies a fee detail within a work order' do
      expect(service.verify_fee_detail_in_work_order(work_order, fee_detail.id, 'rejected', '金额不符')).to be_truthy
      expect(fee_detail.reload.verification_status).to eq('rejected')
    end
  end

  describe '#get_verification_history' do
    let(:fee_detail) { create(:fee_detail, reimbursement: reimbursement) }
    let(:selection1) { create(:fee_detail_selection, fee_detail: fee_detail, audit_work_order: work_order, verification_status: 'pending') }
    let(:selection2) { create(:fee_detail_selection, fee_detail: fee_detail, audit_work_order: work_order, verification_status: 'approved') }

    it 'returns the verification history of a fee detail' do
      history = service.get_verification_history(fee_detail)
      expect(history.size).to eq(2)
      expect(history.first.verification_status).to eq('approved')
      expect(history.last.verification_status).to eq('pending')
    end
  end

  describe '#get_fee_details_by_status' do
    let(:fee_detail1) { create(:fee_detail, reimbursement: reimbursement, verification_status: 'approved') }
    let(:fee_detail2) { create(:fee_detail, reimbursement: reimbursement, verification_status: 'rejected') }
    let(:fee_detail3) { create(:fee_detail, reimbursement: reimbursement, verification_status: 'problematic') }

    it 'returns fee details filtered by status' do
      expect(service.get_fee_details_by_status('approved').size).to eq(1)
      expect(service.get_fee_details_by_status('rejected').size).to eq(1)
      expect(service.get_fee_details_by_status('problematic').size).to eq(1)
    end

    it 'returns fee details filtered by status and reimbursement' do
      other_reimbursement = create(:reimbursement, status: 'processing')
      create(:fee_detail, reimbursement: other_reimbursement, verification_status: 'approved')

      expect(service.get_fee_details_by_status('approved', reimbursement.id).size).to eq(1)
    end
  end
end