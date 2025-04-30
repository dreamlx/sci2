# spec/models/communication_work_order_spec.rb
require 'rails_helper'

RSpec.describe CommunicationWorkOrder, type: :model do
  let(:reimbursement) { create(:reimbursement) }
  let(:admin_user) { create(:admin_user) }

  # 验证测试
  describe "validations" do
    it { should validate_presence_of(:reimbursement_id) }
    it { should validate_presence_of(:type) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[pending processing approved rejected]) }
    # Rewrite validations using manual checks as .if is not supported by shoulda-matchers
    it "validates presence of resolution_summary if approved or rejected" do
      communication_work_order = build(:communication_work_order, status: 'approved', resolution_summary: nil)
      expect(communication_work_order).not_to be_valid
      expect(communication_work_order.errors[:resolution_summary]).to include("不能为空")

      communication_work_order.status = 'rejected'
      communication_work_order.resolution_summary = nil
      expect(communication_work_order).not_to be_valid
      expect(communication_work_order.errors[:resolution_summary]).to include("不能为空")

      communication_work_order.status = 'pending'
      communication_work_order.resolution_summary = nil
      expect(communication_work_order).to be_valid

      communication_work_order.status = 'processing'
      communication_work_order.resolution_summary = nil
      expect(communication_work_order).to be_valid
    end

    it "validates presence of problem_type if rejected" do
      communication_work_order = build(:communication_work_order, status: 'rejected', problem_type: nil)
      expect(communication_work_order).not_to be_valid
      expect(communication_work_order.errors[:problem_type]).to include("不能为空")

      communication_work_order.status = 'approved'
      communication_work_order.problem_type = nil
      expect(communication_work_order).to be_valid
    end
  end

  # 关联测试
  describe "associations" do
    it { should belong_to(:reimbursement) }
    it { should belong_to(:creator).class_name('AdminUser').optional }
    it { should have_many(:fee_detail_selections).dependent(:destroy) }
    it { should have_many(:fee_details).through(:fee_detail_selections) }
    it { should have_many(:work_order_status_changes).dependent(:destroy) }
    it { should have_many(:communication_records).with_foreign_key('communication_work_order_id').dependent(:destroy).inverse_of(:communication_work_order) }
  end

  # 状态机测试
  describe "state machine" do
    let(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement) }

    context "when in pending state" do
      it "can transition to processing" do
        expect(communication_work_order.status).to eq("pending")
        expect(communication_work_order.start_processing!).to be_truthy
        expect(communication_work_order.status).to eq("processing")
      end

      it "can transition directly to approved" do
        communication_work_order.processing_opinion = "审核通过"
        expect(communication_work_order.approve!).to be_truthy
        expect(communication_work_order.status).to eq("approved")
      end

      it "can transition directly to rejected" do
        communication_work_order.processing_opinion = "否决"
        # problem_type is required for rejected state based on validations
        communication_work_order.problem_type = "documentation_issue"
        expect(communication_work_order.reject!).to be_truthy
        expect(communication_work_order.status).to eq("rejected")
      end
    end

    context "when in processing state" do
      let(:communication_work_order) { create(:communication_work_order, :processing, reimbursement: reimbursement) }

      it "can transition to approved" do
        expect(communication_work_order.approve!).to be_truthy
        expect(communication_work_order.status).to eq("approved")
      end

      it "can transition to rejected" do
        communication_work_order.problem_type = "documentation_issue"
        expect(communication_work_order.reject!).to be_truthy
        expect(communication_work_order.status).to eq("rejected")
      end
    end

    context "when in approved state" do
      let(:communication_work_order) { create(:communication_work_order, :approved, reimbursement: reimbursement) }

      it "cannot transition to any other state" do
        expect { communication_work_order.start_processing! }.to raise_error(StateMachines::InvalidTransition)
        expect { communication_work_order.reject! }.to raise_error(StateMachines::InvalidTransition)
        expect(communication_work_order.status).to eq("approved")
      end
    end

    context "when in rejected state" do
      let(:communication_work_order) { create(:communication_work_order, :rejected, reimbursement: reimbursement) }

      it "cannot transition to any other state" do
        expect { communication_work_order.start_processing! }.to raise_error(StateMachines::InvalidTransition)
        expect { communication_work_order.approve! }.to raise_error(StateMachines::InvalidTransition)
        expect(communication_work_order.status).to eq("rejected")
      end
    end
  end

  # needs_communication 测试
  describe "needs_communication attribute" do
    let(:communication_work_order) { create(:communication_work_order) }

    it "defaults to false" do
      expect(communication_work_order.needs_communication).to be_falsey
    end

    it "can be marked as needing communication" do
      communication_work_order.mark_needs_communication!
      expect(communication_work_order.needs_communication).to be_truthy
    end

    it "can be unmarked as needing communication" do
      communication_work_order.mark_needs_communication!
      communication_work_order.unmark_needs_communication!
      expect(communication_work_order.needs_communication).to be_falsey
    end

    it "does not affect state transitions" do
      communication_work_order.mark_needs_communication!
      expect(communication_work_order.start_processing!).to be_truthy
      expect(communication_work_order.status).to eq("processing")

      communication_work_order.approve!
      expect(communication_work_order.status).to eq("approved")

      communication_work_order.unmark_needs_communication!
      expect(communication_work_order.reject!).to be_truthy
      expect(communication_work_order.status).to eq("rejected")
    end
  end

  # 沟通记录测试
  describe "#add_communication_record" do
    let(:communication_work_order) { create(:communication_work_order) }

    it "creates a communication record" do
      expect {
        communication_work_order.add_communication_record(
          content: "Test communication",
          communicator_role: "auditor",
          communication_method: "email"
        )
      }.to change(CommunicationRecord, :count).by(1)

      record = CommunicationRecord.last
      expect(record.content).to eq("Test communication")
      expect(record.communicator_role).to eq("auditor")
      expect(record.communication_method).to eq("email")
      expect(record.recorded_at).to be_present
    end

    it "sets communicator_name to current admin user's email if not provided" do
      allow(Current).to receive(:admin_user).and_return(admin_user)

      expect {
        communication_work_order.add_communication_record(
          content: "Test communication",
          communicator_role: "auditor",
          communication_method: "email"
        )
      }.to change(CommunicationRecord, :count).by(1)

      record = CommunicationRecord.last
      expect(record.communicator_name).to eq(admin_user.email)
    end
  end

  # 费用明细选择测试
  describe "#select_fee_detail" do
    let(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement) }
    let(:fee_detail) { create(:fee_detail, reimbursement: reimbursement) }

    it "selects a fee detail" do
      expect {
        communication_work_order.select_fee_detail(fee_detail)
      }.to change(FeeDetailSelection, :count).by(1)

      selection = FeeDetailSelection.last
      expect(selection.fee_detail_id).to eq(fee_detail.id)
      expect(selection.work_order_id).to eq(communication_work_order.id)
      expect(selection.verification_status).to eq(fee_detail.verification_status)
    end

    it "does not select a fee detail if it does not belong to the same reimbursement" do
      other_reimbursement = create(:reimbursement)
      other_fee_detail = create(:fee_detail, reimbursement: other_reimbursement)

      expect {
        communication_work_order.select_fee_detail(other_fee_detail)
      }.not_to change(FeeDetailSelection, :count)
    end
  end

  describe "#select_fee_details" do
    let(:communication_work_order) { create(:communication_work_order, reimbursement: reimbursement) }
    let(:fee_detail1) { create(:fee_detail, reimbursement: reimbursement) }
    let(:fee_detail2) { create(:fee_detail, reimbursement: reimbursement) }

    it "selects multiple fee details" do
      expect {
        communication_work_order.select_fee_details([fee_detail1.id, fee_detail2.id])
      }.to change(FeeDetailSelection, :count).by(2)

      selections = FeeDetailSelection.all
      expect(selections.map(&:fee_detail_id)).to include(fee_detail1.id, fee_detail2.id)
      expect(selections.map(&:work_order_id)).to all(eq(communication_work_order.id))
    end

    it "does not select fee details if they do not belong to the same reimbursement" do
      other_reimbursement = create(:reimbursement)
      other_fee_detail = create(:fee_detail, reimbursement: other_reimbursement)

      expect {
        communication_work_order.select_fee_details([other_fee_detail.id])
      }.not_to change(FeeDetailSelection, :count)
    end
  end

  # Ransackable methods
  describe "ransackable methods" do
    it "includes subclass specific attributes" do
      expect(CommunicationWorkOrder.ransackable_attributes).to include(
        "communication_method", "initiator_role", "resolution_summary", "problem_type", "problem_description", "remark", "processing_opinion", "needs_communication"
      )
    end

    it "includes subclass specific associations" do
      expect(CommunicationWorkOrder.ransackable_associations).to include(
        "communication_records"
      )
    end
  end
end