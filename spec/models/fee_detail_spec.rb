require 'rails_helper'

RSpec.describe FeeDetail, type: :model do
  describe "validations" do
    it { should validate_presence_of(:document_number) }
    it { should validate_presence_of(:fee_type) }
    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }
    it { should validate_presence_of(:verification_status) }
    it { should validate_inclusion_of(:verification_status).in_array(FeeDetail::VERIFICATION_STATUSES) }
  end

  describe "associations" do
    it { should belong_to(:reimbursement).optional }
    it { should have_many(:fee_detail_selections).dependent(:destroy) }
    it { should have_many(:audit_work_orders).through(:fee_detail_selections) }
    it { should have_many(:communication_work_orders).through(:fee_detail_selections) }
  end

  describe "scopes" do
    before do
      create(:fee_detail, verification_status: 'pending')
      create(:fee_detail, verification_status: 'verified')
      create(:fee_detail, verification_status: 'rejected')
      create(:fee_detail, verification_status: 'problematic')
    end

    it "returns pending fee details" do
      expect(FeeDetail.pending.count).to eq(1)
    end

    it "returns verified fee details" do
      expect(FeeDetail.verified.count).to eq(1)
    end

    it "returns rejected fee details" do
      expect(FeeDetail.rejected.count).to eq(1)
    end

    it "returns problematic fee details" do
      expect(FeeDetail.problematic.count).to eq(1)
    end

    it "returns not verified fee details" do
      expect(FeeDetail.not_verified.count).to eq(3)
    end

    it "returns not rejected fee details" do
      expect(FeeDetail.not_rejected.count).to eq(3)
    end

    it "returns fee details requiring action" do
      expect(FeeDetail.requiring_action.count).to eq(2)
    end
  end

  describe "methods" do
    let(:fee_detail) { create(:fee_detail) }

    describe "#mark_as_verified" do
      it "updates verification_status to verified" do
        fee_detail.mark_as_verified
        expect(fee_detail.reload.verification_status).to eq('verified')
      end
    end

    describe "#mark_as_rejected" do
      it "updates verification_status to rejected" do
        fee_detail.mark_as_rejected
        expect(fee_detail.reload.verification_status).to eq('rejected')
      end
    end

    describe "#mark_as_problematic" do
      it "updates verification_status to problematic" do
        fee_detail.mark_as_problematic
        expect(fee_detail.reload.verification_status).to eq('problematic')
      end
    end

    describe "#mark_as_pending" do
      it "updates verification_status to pending" do
        fee_detail.update(verification_status: 'verified')
        fee_detail.mark_as_pending
        expect(fee_detail.reload.verification_status).to eq('pending')
      end
    end

    describe "status check methods" do
      it "returns true for verified? when status is verified" do
        fee_detail.update(verification_status: 'verified')
        expect(fee_detail.verified?).to be_truthy
      end

      it "returns true for rejected? when status is rejected" do
        fee_detail.update(verification_status: 'rejected')
        expect(fee_detail.rejected?).to be_truthy
      end

      it "returns true for problematic? when status is problematic" do
        fee_detail.update(verification_status: 'problematic')
        expect(fee_detail.problematic?).to be_truthy
      end

      it "returns true for pending? when status is pending" do
        expect(fee_detail.pending?).to be_truthy
      end

      it "returns true for requires_action? when status is pending or problematic" do
        expect(fee_detail.requires_action?).to be_truthy
        
        fee_detail.update(verification_status: 'problematic')
        expect(fee_detail.requires_action?).to be_truthy
        
        fee_detail.update(verification_status: 'verified')
        expect(fee_detail.requires_action?).to be_falsey
      end
    end

    describe "selection methods" do
      let(:reimbursement) { create(:reimbursement) }
      let(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
      let(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement) }
      let(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement, audit_work_order: audit_work_order) }

      before do
        # Create selections
        audit_work_order.select_fee_detail(fee_detail)
        communication_work_order.select_fee_detail(fee_detail)
      end

      it "returns latest audit selection" do
        expect(fee_detail.latest_audit_selection).to be_present
        expect(fee_detail.latest_audit_selection.audit_work_order).to eq(audit_work_order)
      end

      it "returns latest communication selection" do
        expect(fee_detail.latest_communication_selection).to be_present
        expect(fee_detail.latest_communication_selection.communication_work_order).to eq(communication_work_order)
      end
    end
  end
end