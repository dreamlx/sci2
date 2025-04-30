# spec/models/audit_work_order_spec.rb
require 'rails_helper'

RSpec.describe AuditWorkOrder, type: :model do
  let(:reimbursement) { create(:reimbursement) }
  let(:admin_user) { create(:admin_user) }

  # 验证测试
  describe "validations" do
    it { should validate_presence_of(:reimbursement_id) }
    it { should validate_presence_of(:type) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[pending processing approved rejected]) }
    
    # 手动测试条件验证，因为 shoulda-matchers 不支持 .if 条件
    it "validates presence of audit_result when approved or rejected" do
      work_order = build(:audit_work_order, reimbursement: reimbursement, status: 'approved', audit_result: nil)
      expect(work_order).not_to be_valid
      expect(work_order.errors[:audit_result]).to include("不能为空")
      
      work_order = build(:audit_work_order, reimbursement: reimbursement, status: 'rejected', audit_result: nil)
      expect(work_order).not_to be_valid
      expect(work_order.errors[:audit_result]).to include("不能为空")
      
      work_order = build(:audit_work_order, reimbursement: reimbursement, status: 'pending', audit_result: nil)
      expect(work_order).to be_valid
    end
    
    it "validates presence of problem_type when rejected" do
      work_order = build(:audit_work_order, reimbursement: reimbursement, status: 'rejected', problem_type: nil, audit_result: 'rejected')
      expect(work_order).not_to be_valid
      expect(work_order.errors[:problem_type]).to include("不能为空")
      
      work_order = build(:audit_work_order, reimbursement: reimbursement, status: 'approved', problem_type: nil, audit_result: 'approved')
      expect(work_order).to be_valid
    end
  end

  # 关联测试
  describe "associations" do
    it { should belong_to(:reimbursement) }
    it { should belong_to(:creator).class_name('AdminUser').optional }
    it { should have_many(:fee_detail_selections).dependent(:destroy) }
    it { should have_many(:fee_details).through(:fee_detail_selections) }
    it { should have_many(:work_order_status_changes).dependent(:destroy) }
  end

  # 状态机测试
  describe "state machine" do
    let(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement) }

    context "when in pending state" do
      it "can transition to processing" do
        expect(audit_work_order.status).to eq("pending")
        expect(audit_work_order.start_processing!).to be_truthy
        expect(audit_work_order.status).to eq("processing")
      end

      # Corrected tests for direct transitions
      it "can transition directly to approved" do
        audit_work_order.processing_opinion = "审核通过"
        expect(audit_work_order.approve!).to be_truthy
        expect(audit_work_order.status).to eq("approved")
      end

      it "can transition directly to rejected" do
        audit_work_order.processing_opinion = "否决"
        # problem_type is required for rejected state based on validations
        audit_work_order.problem_type = "documentation_issue"
        expect(audit_work_order.reject!).to be_truthy
        expect(audit_work_order.status).to eq("rejected")
      end
    end

    context "when in processing state" do
      let(:audit_work_order) { create(:audit_work_order, :processing, reimbursement: reimbursement) }

      it "can transition to approved" do
        expect(audit_work_order.approve!).to be_truthy
        expect(audit_work_order.status).to eq("approved")
      end

      it "can transition to rejected" do
        audit_work_order.problem_type = "documentation_issue"
        expect(audit_work_order.reject!).to be_truthy
        expect(audit_work_order.status).to eq("rejected")
      end
    end

    context "when in approved state" do
      let(:audit_work_order) { create(:audit_work_order, :approved, reimbursement: reimbursement) }

      it "cannot transition to any other state" do
        expect { audit_work_order.start_processing! }.to raise_error(StateMachines::InvalidTransition)
        expect { audit_work_order.reject! }.to raise_error(StateMachines::InvalidTransition)
        expect(audit_work_order.status).to eq("approved")
      end
    end

    context "when in rejected state" do
      let(:audit_work_order) { create(:audit_work_order, :rejected, reimbursement: reimbursement) }

      it "cannot transition to any other state" do
        expect { audit_work_order.start_processing! }.to raise_error(StateMachines::InvalidTransition)
        expect { audit_work_order.approve! }.to raise_error(StateMachines::InvalidTransition)
        expect(audit_work_order.status).to eq("rejected")
      end
    end
  end

  # 费用明细选择测试
  describe "#select_fee_detail" do
    let(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement) }
    let(:fee_detail) { create(:fee_detail, reimbursement: reimbursement) }

    it "selects a fee detail" do
      expect {
        audit_work_order.select_fee_detail(fee_detail)
      }.to change(FeeDetailSelection, :count).by(1)

      selection = FeeDetailSelection.last
      expect(selection.fee_detail_id).to eq(fee_detail.id)
      expect(selection.work_order_id).to eq(audit_work_order.id)
      expect(selection.verification_status).to eq(fee_detail.verification_status)
    end

    it "does not select a fee detail if it does not belong to the same reimbursement" do
      other_reimbursement = create(:reimbursement)
      other_fee_detail = create(:fee_detail, reimbursement: other_reimbursement)

      expect {
        audit_work_order.select_fee_detail(other_fee_detail)
      }.not_to change(FeeDetailSelection, :count)
    end
  end

  describe "#select_fee_details" do
    let(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement) }
    let(:fee_detail1) { create(:fee_detail, reimbursement: reimbursement) }
    let(:fee_detail2) { create(:fee_detail, reimbursement: reimbursement) }

    it "selects multiple fee details" do
      # 确保 audit_work_order 已保存到数据库
      audit_work_order.save!
      
      expect {
        audit_work_order.select_fee_details([fee_detail1.id, fee_detail2.id])
      }.to change(FeeDetailSelection, :count).by(2)

      selections = FeeDetailSelection.all
      expect(selections.map(&:fee_detail_id)).to include(fee_detail1.id, fee_detail2.id)
      expect(selections.map(&:work_order_id)).to all(eq(audit_work_order.id))
    end

    it "does not select fee details if they do not belong to the same reimbursement" do
      other_reimbursement = create(:reimbursement)
      other_fee_detail = create(:fee_detail, reimbursement: other_reimbursement)

      expect {
        audit_work_order.select_fee_details([other_fee_detail.id])
      }.not_to change(FeeDetailSelection, :count)
    end
  end

  # 审核结果和日期测试
  describe "audit_result and audit_date" do
    let(:audit_work_order) { create(:audit_work_order, :processing, reimbursement: reimbursement) }

    context "when approving" do
      it "sets audit_result to 'approved' and audit_date to current time" do
        audit_work_order.approve!
        expect(audit_work_order.audit_result).to eq("approved")
        expect(audit_work_order.audit_date).to be_within(1.second).of(Time.current)
      end
    end

    context "when rejecting" do
      it "sets audit_result to 'rejected' and audit_date to current time" do
        audit_work_order.problem_type = "documentation_issue"
        audit_work_order.reject!
        expect(audit_work_order.audit_result).to eq("rejected")
        expect(audit_work_order.audit_date).to be_within(1.second).of(Time.current)
      end
    end
  end

  # 状态检查方法测试
  describe "state check methods" do
    let(:audit_work_order) { create(:audit_work_order) }

    it "returns true for pending? when status is pending" do
      audit_work_order.update(status: 'pending')
      expect(audit_work_order.pending?).to be_truthy
    end

    it "returns true for processing? when status is processing" do
      audit_work_order.update(status: 'processing')
      expect(audit_work_order.processing?).to be_truthy
    end

    it "returns true for approved? when status is approved" do
      audit_work_order.update(status: 'approved')
      expect(audit_work_order.approved?).to be_truthy
    end

    it "returns true for rejected? when status is rejected" do
      audit_work_order.update(status: 'rejected')
      expect(audit_work_order.rejected?).to be_truthy
    end
  end

  # ActiveAdmin 配置测试
  describe "ransackable methods" do
    it "includes subclass specific attributes" do
      expect(AuditWorkOrder.ransackable_attributes).to include(
        "audit_result", "audit_comment", "audit_date", "vat_verified", "problem_type", "problem_description", "remark", "processing_opinion"
      )
    end

    it "includes subclass specific associations" do
      expect(AuditWorkOrder.ransackable_associations).to eq([])
    end
  end
end