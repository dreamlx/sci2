require 'rails_helper'

RSpec.describe AuditWorkOrder, type: :model do
  describe "validations" do
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:reimbursement_id) }

    context "when status is approved or rejected" do
      it "validates presence of audit_result" do
        audit_work_order = build(:audit_work_order, status: 'approved', audit_result: nil)
        expect(audit_work_order).not_to be_valid
        expect(audit_work_order.errors[:audit_result]).to include("can't be blank")

        audit_work_order = build(:audit_work_order, status: 'rejected', audit_result: nil)
        expect(audit_work_order).not_to be_valid
        expect(audit_work_order.errors[:audit_result]).to include("can't be blank")
      end
    end
  end

  describe "associations" do
    it { should belong_to(:reimbursement) }
    it { should belong_to(:express_receipt_work_order).optional }
    it { should have_many(:communication_work_orders).dependent(:nullify) }
    it { should have_many(:fee_detail_selections).dependent(:destroy) }
    it { should have_many(:fee_details).through(:fee_detail_selections) }
    it { should have_many(:work_order_status_changes).dependent(:destroy) }
  end

  describe "state machine" do
    let(:work_order) { create(:audit_work_order) }

    it "has initial state of pending" do
      expect(work_order.status).to eq('pending')
    end

    context "when starting processing" do
      it "can transition from pending to processing" do
        expect(work_order).to be_pending
        expect(work_order.start_processing).to be_truthy
        expect(work_order).to be_processing
      end
    end

    context "when starting audit" do
      before do
        work_order.update(status: 'processing')
      end

      it "can transition from processing to auditing" do
        expect(work_order).to be_processing
        expect(work_order.start_audit).to be_truthy
        expect(work_order).to be_auditing
      end
    end

    context "when approving" do
      before do
        work_order.update(status: 'auditing')
      end

      it "can transition from auditing to approved" do
        expect(work_order).to be_auditing
        expect(work_order.approve).to be_truthy
        expect(work_order).to be_approved
      end

      it "sets audit_result and audit_date after approval" do
        work_order.approve
        expect(work_order.audit_result).to eq('approved')
        expect(work_order.audit_date).not_to be_nil
      end
    end

    context "when rejecting" do
      context "from auditing" do
        before do
          work_order.update(status: 'auditing')
        end

        it "can transition from auditing to rejected" do
          expect(work_order).to be_auditing
          expect(work_order.reject).to be_truthy
          expect(work_order).to be_rejected
        end

        it "sets audit_result and audit_date after rejection" do
          work_order.reject
          expect(work_order.audit_result).to eq('rejected')
          expect(work_order.audit_date).not_to be_nil
        end
      end

      context "from needs_communication" do
        before do
          work_order.update(status: 'needs_communication')
        end

        it "can transition from needs_communication to rejected" do
          expect(work_order).to be_needs_communication
          expect(work_order.reject).to be_truthy
          expect(work_order).to be_rejected
        end
      end
    end

    context "when needing communication" do
      before do
        work_order.update(status: 'auditing')
      end

      it "can transition from auditing to needs_communication" do
        expect(work_order).to be_auditing
        expect(work_order.need_communication).to be_truthy
        expect(work_order).to be_needs_communication
      end
    end

    context "when resuming audit" do
      before do
        work_order.update(status: 'needs_communication')
      end

      it "can transition from needs_communication to auditing" do
        expect(work_order).to be_needs_communication
        expect(work_order.resume_audit).to be_truthy
        expect(work_order).to be_auditing
      end
    end

    context "when completing" do
      context "from approved" do
        before do
          work_order.update(status: 'approved', audit_result: 'approved', audit_date: Time.current)
        end

        it "can transition from approved to completed" do
          expect(work_order).to be_approved
          expect(work_order.complete).to be_truthy
          expect(work_order).to be_completed
        end
      end

      context "from rejected" do
        before do
          work_order.update(status: 'rejected', audit_result: 'rejected', audit_date: Time.current)
        end

        it "can transition from rejected to completed" do
          expect(work_order).to be_rejected
          expect(work_order.complete).to be_truthy
          expect(work_order).to be_completed
        end
      end
    end
  end

  describe "#create_communication_work_order" do
    let(:work_order) { create(:audit_work_order, :auditing) }
    let(:fee_detail) { create(:fee_detail, document_number: work_order.reimbursement.invoice_number) }

    it "creates a communication work order" do
      expect {
        work_order.create_communication_work_order(
          communication_method: "email",
          initiator_role: "auditor"
        )
      }.to change(CommunicationWorkOrder, :count).by(1)
    end

    it "changes status to needs_communication" do
      work_order.create_communication_work_order(
        communication_method: "email",
        initiator_role: "auditor"
      )
      expect(work_order.reload.status).to eq('needs_communication')
    end

    it "associates fee details if provided" do
      comm_order = work_order.create_communication_work_order(
        communication_method: "email",
        initiator_role: "auditor",
        fee_detail_ids: [fee_detail.id]
      )

      expect(comm_order.fee_details).to include(fee_detail)
      expect(fee_detail.reload.verification_status).to eq('problematic')
    end
  end

  describe "#verify_fee_detail" do
    let(:work_order) { create(:audit_work_order, :with_fee_details) }
    let(:fee_detail) { work_order.fee_details.first }

    it "updates fee detail selection verification status" do
      work_order.verify_fee_detail(fee_detail, 'verified', 'Verified OK')
      selection = work_order.fee_detail_selections.find_by(fee_detail: fee_detail)
      
      expect(selection.verification_status).to eq('verified')
      expect(selection.verification_comment).to eq('Verified OK')
      expect(selection.verified_at).not_to be_nil
    end

    it "updates fee detail verification status" do
      work_order.verify_fee_detail(fee_detail, 'verified')
      expect(fee_detail.reload.verification_status).to eq('verified')

      another_fee_detail = work_order.fee_details.second
      work_order.verify_fee_detail(another_fee_detail, 'rejected')
      expect(another_fee_detail.reload.verification_status).to eq('rejected')

      third_fee_detail = work_order.fee_details.third
      work_order.verify_fee_detail(third_fee_detail, 'problematic')
      expect(third_fee_detail.reload.verification_status).to eq('problematic')
    end

    it "returns false if fee detail is not associated with the work order" do
      unrelated_fee_detail = create(:fee_detail)
      expect(work_order.verify_fee_detail(unrelated_fee_detail, 'verified')).to be_falsey
    end
  end

  describe "#select_fee_detail" do
    let(:work_order) { create(:audit_work_order) }
    let(:fee_detail) { create(:fee_detail, document_number: work_order.reimbursement.invoice_number) }

    it "creates a fee detail selection" do
      expect {
        work_order.select_fee_detail(fee_detail)
      }.to change(FeeDetailSelection, :count).by(1)
    end

    it "sets verification status to pending" do
      selection = work_order.select_fee_detail(fee_detail)
      expect(selection.verification_status).to eq('pending')
    end

    it "does not create duplicate selections" do
      work_order.select_fee_detail(fee_detail)
      expect {
        work_order.select_fee_detail(fee_detail)
      }.not_to change(FeeDetailSelection, :count)
    end
  end

  describe "#select_fee_details" do
    let(:work_order) { create(:audit_work_order) }
    let(:fee_details) do
      [
        create(:fee_detail, document_number: work_order.reimbursement.invoice_number),
        create(:fee_detail, document_number: work_order.reimbursement.invoice_number)
      ]
    end

    it "creates multiple fee detail selections" do
      expect {
        work_order.select_fee_details(fee_details.map(&:id))
      }.to change(FeeDetailSelection, :count).by(2)
    end
  end

  describe "status change recording" do
    let(:work_order) { create(:audit_work_order) }

    it "records status change when status changes" do
      expect {
        work_order.start_processing
      }.to change(WorkOrderStatusChange, :count).by(1)

      status_change = WorkOrderStatusChange.last
      expect(status_change.work_order_type).to eq('audit')
      expect(status_change.work_order_id).to eq(work_order.id)
      expect(status_change.from_status).to eq('pending')
      expect(status_change.to_status).to eq('processing')
    end
  end

  describe "#all_fees_verified?" do
    let(:work_order) { create(:audit_work_order, :with_fee_details) }

    it "returns false when not all fees are verified or rejected" do
      expect(work_order.all_fees_verified?).to be_falsey
    end

    it "returns true when all fees are verified or rejected" do
      work_order.fee_details.each_with_index do |fee_detail, index|
        status = index.even? ? 'verified' : 'rejected'
        work_order.verify_fee_detail(fee_detail, status)
      end
      expect(work_order.all_fees_verified?).to be_truthy
    end
  end
end