require 'rails_helper'

RSpec.describe FeeDetailSelection, type: :model do
  describe "validations" do
    it { should validate_presence_of(:verification_status) }
    it { should validate_inclusion_of(:verification_status).in_array(FeeDetailSelection::VERIFICATION_STATUSES) }

    context "when associated with audit work order" do
      subject { build(:fee_detail_selection, :for_audit_work_order) }
      it { should validate_uniqueness_of(:fee_detail_id).scoped_to(:audit_work_order_id) }
    end

    context "when associated with communication work order" do
      subject { build(:fee_detail_selection, :for_communication_work_order) }
      it { should validate_uniqueness_of(:fee_detail_id).scoped_to(:communication_work_order_id) }
    end

    it "requires association with either audit or communication work order" do
      selection = build(:fee_detail_selection, audit_work_order_id: nil, communication_work_order_id: nil)
      expect(selection).not_to be_valid
      expect(selection.errors[:base]).to include("必须关联到审核工单或沟通工单")
    end

    it "cannot be associated with both audit and communication work order" do
      selection = build(:fee_detail_selection, :for_audit_work_order)
      selection.communication_work_order = build(:communication_work_order)
      expect(selection).not_to be_valid
      expect(selection.errors[:base]).to include("不能同时关联到审核工单和沟通工单")
    end
  end

  describe "associations" do
    it { should belong_to(:fee_detail) }
    it { should belong_to(:audit_work_order).optional }
    it { should belong_to(:communication_work_order).optional }
  end

  describe "scopes" do
    before do
      create(:fee_detail_selection, :for_audit_work_order, verification_status: 'pending')
      create(:fee_detail_selection, :for_audit_work_order, verification_status: 'verified')
      create(:fee_detail_selection, :for_audit_work_order, verification_status: 'rejected')
      create(:fee_detail_selection, :for_communication_work_order, verification_status: 'problematic')
    end

    it "returns pending selections" do
      expect(FeeDetailSelection.pending.count).to eq(1)
    end

    it "returns verified selections" do
      expect(FeeDetailSelection.verified.count).to eq(1)
    end

    it "returns rejected selections" do
      expect(FeeDetailSelection.rejected.count).to eq(1)
    end

    it "returns problematic selections" do
      expect(FeeDetailSelection.problematic.count).to eq(1)
    end

    it "returns selections for audit work orders" do
      expect(FeeDetailSelection.for_audit_work_orders.count).to eq(3)
    end

    it "returns selections for communication work orders" do
      expect(FeeDetailSelection.for_communication_work_orders.count).to eq(1)
    end
  end

  describe "methods" do
    let(:selection) { create(:fee_detail_selection, :for_audit_work_order) }

    describe "#mark_as_verified" do
      it "updates verification_status to verified" do
        selection.mark_as_verified("验证通过", 1)
        expect(selection.reload.verification_status).to eq('verified')
        expect(selection.verification_comment).to eq('验证通过')
        expect(selection.verified_by).to eq(1)
        expect(selection.verified_at).not_to be_nil
      end
    end

    describe "#mark_as_rejected" do
      it "updates verification_status to rejected" do
        selection.mark_as_rejected("验证拒绝", 1)
        expect(selection.reload.verification_status).to eq('rejected')
        expect(selection.verification_comment).to eq('验证拒绝')
        expect(selection.verified_by).to eq(1)
        expect(selection.verified_at).not_to be_nil
      end
    end

    describe "#mark_as_problematic" do
      it "updates verification_status to problematic" do
        selection.mark_as_problematic("验证有问题", 1)
        expect(selection.reload.verification_status).to eq('problematic')
        expect(selection.verification_comment).to eq('验证有问题')
        expect(selection.verified_by).to eq(1)
        expect(selection.verified_at).not_to be_nil
      end
    end

    describe "status check methods" do
      it "returns true for verified? when status is verified" do
        selection.update(verification_status: 'verified')
        expect(selection.verified?).to be_truthy
      end

      it "returns true for rejected? when status is rejected" do
        selection.update(verification_status: 'rejected')
        expect(selection.rejected?).to be_truthy
      end

      it "returns true for problematic? when status is problematic" do
        selection.update(verification_status: 'problematic')
        expect(selection.problematic?).to be_truthy
      end

      it "returns true for pending? when status is pending" do
        expect(selection.pending?).to be_truthy
      end
    end

    describe "#work_order" do
      it "returns audit work order when associated with audit work order" do
        expect(selection.work_order).to eq(selection.audit_work_order)
      end

      it "returns communication work order when associated with communication work order" do
        selection = create(:fee_detail_selection, :for_communication_work_order)
        expect(selection.work_order).to eq(selection.communication_work_order)
      end
    end

    describe "#work_order_type" do
      it "returns 'audit' when associated with audit work order" do
        expect(selection.work_order_type).to eq('audit')
      end

      it "returns 'communication' when associated with communication work order" do
        selection = create(:fee_detail_selection, :for_communication_work_order)
        expect(selection.work_order_type).to eq('communication')
      end

      it "returns nil when not associated with any work order" do
        selection = build(:fee_detail_selection, audit_work_order_id: nil, communication_work_order_id: nil)
        expect(selection.work_order_type).to be_nil
      end
    end
  end
end