require 'rails_helper'

RSpec.describe CommunicationWorkOrder, type: :model do
  describe "validations" do
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:reimbursement_id) }
    it { should validate_presence_of(:audit_work_order_id) }
  end

  describe "associations" do
    it { should belong_to(:reimbursement) }
    it { should belong_to(:audit_work_order) }
    it { should have_many(:communication_records).dependent(:destroy) }
    it { should have_many(:fee_detail_selections).dependent(:destroy) }
    it { should have_many(:fee_details).through(:fee_detail_selections) }
    it { should have_many(:work_order_status_changes).dependent(:destroy) }
  end

  describe "state machine" do
    let(:work_order) { create(:communication_work_order) }

    it "has initial state of open" do
      expect(work_order.status).to eq('open')
    end

    context "when starting communication" do
      it "can transition from open to in_progress" do
        expect(work_order).to be_open
        expect(work_order.start_communication).to be_truthy
        expect(work_order).to be_in_progress
      end
    end

    context "when resolving" do
      before do
        work_order.update(status: 'in_progress')
      end

      it "can transition from in_progress to resolved" do
        expect(work_order).to be_in_progress
        expect(work_order.resolve).to be_truthy
        expect(work_order).to be_resolved
      end

      it "notifies parent work order after resolution" do
        # Set parent work order to needs_communication
        work_order.audit_work_order.update(status: 'needs_communication')
        
        # Resolve communication work order
        work_order.resolve
        
        # Check if parent work order status changed
        expect(work_order.audit_work_order.reload.status).to eq('auditing')
      end
    end

    context "when marking unresolved" do
      before do
        work_order.update(status: 'in_progress')
      end

      it "can transition from in_progress to unresolved" do
        expect(work_order).to be_in_progress
        expect(work_order.mark_unresolved).to be_truthy
        expect(work_order).to be_unresolved
      end

      it "notifies parent work order after marking unresolved" do
        # Set parent work order to needs_communication
        work_order.audit_work_order.update(status: 'needs_communication')
        
        # Mark communication work order as unresolved
        work_order.mark_unresolved
        
        # Check if parent work order status changed
        expect(work_order.audit_work_order.reload.status).to eq('auditing')
      end
    end

    context "when closing" do
      context "from resolved" do
        before do
          work_order.update(status: 'resolved')
        end

        it "can transition from resolved to closed" do
          expect(work_order).to be_resolved
          expect(work_order.close).to be_truthy
          expect(work_order).to be_closed
        end
      end

      context "from unresolved" do
        before do
          work_order.update(status: 'unresolved')
        end

        it "can transition from unresolved to closed" do
          expect(work_order).to be_unresolved
          expect(work_order.close).to be_truthy
          expect(work_order).to be_closed
        end
      end
    end
  end

  describe "#add_communication_record" do
    let(:work_order) { create(:communication_work_order) }

    it "creates a communication record" do
      expect {
        work_order.add_communication_record(
          content: "测试沟通内容",
          communicator_role: "auditor",
          communicator_name: "测试人员",
          communication_method: "email"
        )
      }.to change(CommunicationRecord, :count).by(1)
    end

    it "associates the record with the work order" do
      record = work_order.add_communication_record(
        content: "测试沟通内容",
        communicator_role: "auditor"
      )
      expect(record.communication_work_order).to eq(work_order)
    end
  end

  describe "#select_fee_detail" do
    let(:work_order) { create(:communication_work_order) }
    let(:fee_detail) { create(:fee_detail, document_number: work_order.reimbursement.invoice_number) }

    it "creates a fee detail selection" do
      expect {
        work_order.select_fee_detail(fee_detail)
      }.to change(FeeDetailSelection, :count).by(1)
    end

    it "sets verification status to problematic" do
      selection = work_order.select_fee_detail(fee_detail)
      expect(selection.verification_status).to eq('problematic')
    end

    it "does not create duplicate selections" do
      work_order.select_fee_detail(fee_detail)
      expect {
        work_order.select_fee_detail(fee_detail)
      }.not_to change(FeeDetailSelection, :count)
    end
  end

  describe "#resolve_fee_detail_issue" do
    let(:work_order) { create(:communication_work_order, :with_fee_details) }
    let(:fee_detail) { work_order.fee_details.first }

    it "updates fee detail selection verification comment" do
      work_order.resolve_fee_detail_issue(fee_detail, "问题已解决")
      selection = work_order.fee_detail_selections.find_by(fee_detail: fee_detail)
      expect(selection.verification_comment).to eq("问题已解决")
    end

    it "returns false if fee detail is not associated with the work order" do
      unrelated_fee_detail = create(:fee_detail)
      expect(work_order.resolve_fee_detail_issue(unrelated_fee_detail, "问题已解决")).to be_falsey
    end
  end

  describe "status change recording" do
    let(:work_order) { create(:communication_work_order) }

    it "records status change when status changes" do
      expect {
        work_order.start_communication
      }.to change(WorkOrderStatusChange, :count).by(1)

      status_change = WorkOrderStatusChange.last
      expect(status_change.work_order_type).to eq('communication')
      expect(status_change.work_order_id).to eq(work_order.id)
      expect(status_change.from_status).to eq('open')
      expect(status_change.to_status).to eq('in_progress')
    end
  end
end