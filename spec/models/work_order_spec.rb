# spec/models/work_order_spec.rb
require 'rails_helper'

RSpec.describe WorkOrder, type: :model do
  # Use subclasses for testing as the base class is abstract
  let(:audit_work_order) { build(:audit_work_order) }
  let(:communication_work_order) { build(:communication_work_order) }
  let(:admin_user) { create(:admin_user) }

  # Validations
  describe "validations" do
    it { should validate_presence_of(:reimbursement_id) }
    it { should validate_presence_of(:type) }
    it { should validate_presence_of(:status) }
  end

  # Associations
  describe "associations" do
    it { should belong_to(:reimbursement) }
    it { should belong_to(:creator).class_name('AdminUser').optional }
    it { should have_many(:fee_detail_selections).dependent(:destroy) }
    it { should have_many(:fee_details).through(:fee_detail_selections) }
    it { should have_many(:work_order_status_changes).dependent(:destroy) }
  end

  # State check methods (moved from reimbursement_spec.rb)
  describe "state check methods" do
    # Test using a subclass instance
    it "returns true for pending? when status is pending" do
      work_order = build(:audit_work_order, status: 'pending')
      expect(work_order.pending?).to be_truthy
    end

    it "returns true for processing? when status is processing" do
      work_order = build(:audit_work_order, status: 'processing')
      expect(work_order.processing?).to be_truthy
    end

    it "returns true for approved? when status is approved" do
      work_order = build(:audit_work_order, status: 'approved')
      expect(work_order.approved?).to be_truthy
    end

    it "returns true for rejected? when status is rejected" do
      work_order = build(:audit_work_order, status: 'rejected')
      expect(work_order.rejected?).to be_truthy
    end

    it "returns true for waiting_completion? when status is waiting_completion" do
      # waiting_completion is a status on Reimbursement, not WorkOrder.
      # This test seems misplaced here. Removing it.
      # work_order = build(:audit_work_order, status: 'waiting_completion')
      # expect(work_order.waiting_completion?).to be_truthy
    end
  end

  # Callbacks
  describe "callbacks" do
    describe "record_status_change" do
      let(:work_order) { create(:audit_work_order) }
      let(:admin_user) { create(:admin_user) }

      before do
        # Mock Current.admin_user for the callback
        allow(Current).to receive(:admin_user).and_return(admin_user)
      end

      it "records status change after update" do
        expect {
          work_order.update(status: 'processing')
        }.to change(WorkOrderStatusChange, :count).by(2)

        status_change = work_order.work_order_status_changes.last
        expect(status_change.from_status).to eq("pending")
        expect(status_change.to_status).to eq("processing")
        expect(status_change.changer_id).to eq(admin_user.id)
        expect(status_change.changed_at).to be_present
      end
    end

    describe "update_reimbursement_status_on_create" do
      let(:reimbursement) { create(:reimbursement) }

      # Test using AuditWorkOrder subclass
      it "calls start_processing! on reimbursement if it's pending for AuditWorkOrder" do
        work_order = build(:audit_work_order, reimbursement: reimbursement)
        allow(reimbursement).to receive(:pending?).and_return(true)
        expect(reimbursement).to receive(:start_processing!)
        work_order.run_callbacks(:create) # Manually run create callbacks
      end

      it "doesn't call start_processing! if reimbursement is not pending for AuditWorkOrder" do
        work_order = build(:audit_work_order, reimbursement: reimbursement)
        allow(reimbursement).to receive(:pending?).and_return(false)
        expect(reimbursement).not_to receive(:start_processing!)
        work_order.run_callbacks(:create)
      end

      # Test using CommunicationWorkOrder subclass
      it "calls start_processing! on reimbursement if it's pending for CommunicationWorkOrder" do
        work_order = build(:communication_work_order, reimbursement: reimbursement)
        allow(reimbursement).to receive(:pending?).and_return(true)
        expect(reimbursement).to receive(:start_processing!)
        work_order.run_callbacks(:create)
      end

      it "doesn't call start_processing! if reimbursement is not pending for CommunicationWorkOrder" do
        work_order = build(:communication_work_order, reimbursement: reimbursement)
        allow(reimbursement).to receive(:pending?).and_return(false)
        expect(reimbursement).not_to receive(:start_processing!)
        work_order.run_callbacks(:create)
      end

      # ExpressReceiptWorkOrder should not trigger start_processing! on create
      it "doesn't call start_processing! on reimbursement for ExpressReceiptWorkOrder" do
        reimbursement = create(:reimbursement)
        work_order = build(:express_receipt_work_order, reimbursement: reimbursement)
        expect(reimbursement).not_to receive(:start_processing!)
        work_order.run_callbacks(:create)
      end
    end

    describe "set_status_based_on_processing_opinion" do
      # Test using AuditWorkOrder subclass
      context "when processing opinion is '审核通过' for AuditWorkOrder" do
        it "sets status to 'approved'" do
          work_order = build(:audit_work_order, status: 'pending', processing_opinion: "审核通过")
          work_order.send(:set_status_based_on_processing_opinion)
          expect(work_order.status).to eq("approved")
        end
      end

      context "when processing opinion is '否决' for AuditWorkOrder" do
        it "sets status to 'rejected'" do
          work_order = build(:audit_work_order, status: 'pending', processing_opinion: "否决")
          work_order.send(:set_status_based_on_processing_opinion)
          expect(work_order.status).to eq("rejected")
        end
      end

      context "when processing opinion is not empty and not '审核通过' or '否决' for AuditWorkOrder" do
        it "sets status to 'processing' if status is 'pending'" do
          work_order = build(:audit_work_order, status: "pending", processing_opinion: "其他意见")
          work_order.send(:set_status_based_on_processing_opinion)
          expect(work_order.status).to eq("processing")
        end

        it "keeps the current status if not 'pending'" do
           work_order = build(:audit_work_order, status: "processing", processing_opinion: "其他意见")
           work_order.send(:set_status_based_on_processing_opinion)
           expect(work_order.status).to eq("processing")
        end
      end

      context "when processing opinion is empty for AuditWorkOrder" do
        it "keeps the current status" do
          work_order = build(:audit_work_order, status: "pending", processing_opinion: "")
          work_order.send(:set_status_based_on_processing_opinion)
          expect(work_order.status).to eq("pending")
        end
      end

      # Test using CommunicationWorkOrder subclass
       context "when processing opinion is '审核通过' for CommunicationWorkOrder" do
        it "sets status to 'approved'" do
          work_order = build(:communication_work_order, status: 'pending', processing_opinion: "审核通过")
          work_order.send(:set_status_based_on_processing_opinion)
          expect(work_order.status).to eq("approved")
        end
      end

      context "when processing opinion is '否决' for CommunicationWorkOrder" do
        it "sets status to 'rejected'" do
          work_order = build(:communication_work_order, status: 'pending', processing_opinion: "否决")
          work_order.send(:set_status_based_on_processing_opinion)
          expect(work_order.status).to eq("rejected")
        end
      end

      context "when processing opinion is not empty and not '审核通过' or '否决' for CommunicationWorkOrder" do
        it "sets status to 'processing' if status is 'pending'" do
          work_order = build(:communication_work_order, status: "pending", processing_opinion: "其他意见")
          work_order.send(:set_status_based_on_processing_opinion)
          expect(work_order.status).to eq("processing")
        end

         it "keeps the current status if not 'pending'" do
           work_order = build(:communication_work_order, status: "processing", processing_opinion: "其他意见")
           work_order.send(:set_status_based_on_processing_opinion)
           expect(work_order.status).to eq("processing")
        end
      end

      context "when processing opinion is empty for CommunicationWorkOrder" do
        it "keeps the current status" do
          work_order = build(:communication_work_order, status: "pending", processing_opinion: "")
          work_order.send(:set_status_based_on_processing_opinion)
          expect(work_order.status).to eq("pending")
        end
      end

      # ExpressReceiptWorkOrder should not be affected by processing_opinion
      it "does not change status based on processing_opinion for ExpressReceiptWorkOrder" do
        work_order = build(:express_receipt_work_order, status: 'completed', processing_opinion: "审核通过")
        work_order.send(:set_status_based_on_processing_opinion)
        expect(work_order.status).to eq("completed")
      end
    end
  end

  # Status change recording (consolidated from other specs)
  describe "status change recording" do
    let(:reimbursement) { create(:reimbursement) }
    let(:admin_user) { create(:admin_user) }

    before do
      # Mock Current.admin_user
      allow(Current).to receive(:admin_user).and_return(admin_user)
    end

    # Test using AuditWorkOrder subclass
    it "records status change when transitioning from pending to processing for AuditWorkOrder" do
      work_order = create(:audit_work_order, reimbursement: reimbursement)
      # Mock the private method call to avoid testing its implementation here
      allow(work_order).to receive(:update_associated_fee_details_status)

      expect {
        work_order.update(status: 'processing')
      }.to change(WorkOrderStatusChange, :count).by(1)

      status_change = work_order.work_order_status_changes.last
      expect(status_change.from_status).to eq("pending")
      expect(status_change.to_status).to eq("processing")
      expect(status_change.changer_id).to eq(admin_user.id)
      expect(status_change.changed_at).to be_present
    end

    # Test using CommunicationWorkOrder subclass
     it "records status change when transitioning from pending to processing for CommunicationWorkOrder" do
      work_order = create(:communication_work_order, reimbursement: reimbursement)
      # Mock the private method call to avoid testing its implementation here
      allow(work_order).to receive(:update_associated_fee_details_status)

      expect {
        work_order.update(status: 'processing')
      }.to change(WorkOrderStatusChange, :count).by(1)

      status_change = work_order.work_order_status_changes.last
      expect(status_change.from_status).to eq("pending")
      expect(status_change.to_status).to eq("processing")
      expect(status_change.changer_id).to eq(admin_user.id)
      expect(status_change.changed_at).to be_present
    end

    # Add more tests for other transitions and subclasses as needed
  end

  # Class method tests
  describe ".sti_name" do
    it "returns the class name" do
      # Test using a subclass
      expect(AuditWorkOrder.sti_name).to eq("AuditWorkOrder")
      expect(CommunicationWorkOrder.sti_name).to eq("CommunicationWorkOrder")
      expect(ExpressReceiptWorkOrder.sti_name).to eq("ExpressReceiptWorkOrder")
    end
  end

  # Ransackable methods (inherited from WorkOrder base class)
  describe "ransackable methods" do
    it "includes common attributes" do
      expect(WorkOrder.ransackable_attributes).to include(
        "id", "reimbursement_id", "type", "status", "created_by", "created_at", "updated_at"
      )
    end

    it "includes common associations" do
      expect(WorkOrder.ransackable_associations).to include(
        "reimbursement", "creator", "fee_detail_selections", "fee_details", "work_order_status_changes"
      )
    end
  end
end