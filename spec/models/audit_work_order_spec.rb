# spec/models/audit_work_order_spec.rb
require 'rails_helper'

RSpec.describe AuditWorkOrder, type: :model do
  # 验证测试（不依赖其他模型）
  describe "validations" do
    it { should validate_inclusion_of(:status).in_array(%w[pending processing approved rejected]) }

    context "when approved or rejected" do
      before do
        allow(subject).to receive(:approved?).and_return(true)
      end

      it { should validate_presence_of(:audit_result) }
    end

    context "when rejected" do
      before do
        allow(subject).to receive(:rejected?).and_return(true)
      end

      it { should validate_presence_of(:problem_type) }
    end
  end

  # 关联方法测试（使用 respond_to 而不是实际测试关联）
  describe "association methods" do
    it { should respond_to(:communication_work_orders) }
  end

  # 状态机测试
  describe "state machine" do
    let(:reimbursement) { create(:reimbursement) }
    let(:work_order) { build(:audit_work_order, reimbursement: reimbursement) }

    context "when in pending state" do
      it "can transition to processing" do
        # 使用 stub 模拟 update_associated_fee_details_status 方法
        allow(work_order).to receive(:update_associated_fee_details_status)

        expect(work_order.status).to eq("pending")
        expect(work_order.start_processing!).to be_truthy
        expect(work_order.status).to eq("processing")

        # 验证调用了 update_associated_fee_details_status 方法
        expect(work_order).to have_received(:update_associated_fee_details_status).with('problematic')
      end
    end

    context "when in processing state" do
      let(:work_order) { build(:audit_work_order, :processing, reimbursement: reimbursement) }

      before do
        allow(work_order).to receive(:update_associated_fee_details_status)
      end

      it "can transition to approved" do
        expect(work_order.approve!).to be_truthy
        expect(work_order.status).to eq("approved")
        expect(work_order.audit_result).to eq("approved")
        expect(work_order.audit_date).to be_present

        # 验证调用了 update_associated_fee_details_status 方法
        expect(work_order).to have_received(:update_associated_fee_details_status).with('verified')
      end

      it "can transition to rejected" do
        work_order.problem_type = "测试问题类型"
        expect(work_order.reject!).to be_truthy
        expect(work_order.status).to eq("rejected")
        expect(work_order.audit_result).to eq("rejected")
        expect(work_order.audit_date).to be_present

        # 验证调用了 update_associated_fee_details_status 方法
        expect(work_order).to have_received(:update_associated_fee_details_status).with('problematic')
      end
    end
  end

  # 费用明细选择方法测试
  describe "#select_fee_detail" do
    let(:reimbursement) { build_stubbed(:reimbursement, invoice_number: "R123456") }
    let(:work_order) { build_stubbed(:audit_work_order, reimbursement: reimbursement) }
    let(:fee_detail) { build_stubbed(:fee_detail, document_number: "R123456", verification_status: 'pending') }
    let(:fee_detail_selection) { build_stubbed(:fee_detail_selection) }

    it "creates a new fee detail selection" do
      # 使用 stub 模拟 fee_detail_selections 关联
      allow(work_order).to receive_message_chain(:fee_detail_selections, :find_or_create_by!).and_return(fee_detail_selection)

      result = work_order.select_fee_detail(fee_detail)
      expect(result).to eq(fee_detail_selection)
    end

    it "returns nil if fee detail doesn't belong to the same reimbursement" do
      other_fee_detail = build_stubbed(:fee_detail, document_number: "R999999")
      result = work_order.select_fee_detail(other_fee_detail)
      expect(result).to be_nil
    end
  end

  describe "#select_fee_details" do
    let(:reimbursement) { build_stubbed(:reimbursement, invoice_number: "R123456") }
    let(:work_order) { build_stubbed(:audit_work_order, reimbursement: reimbursement) }
    let(:fee_detail_ids) { [1, 2, 3] }

    it "selects multiple fee details" do
      # 使用 stub 模拟 FeeDetail.where 查询
      fee_details = [
        build_stubbed(:fee_detail, id: 1),
        build_stubbed(:fee_detail, id: 2),
        build_stubbed(:fee_detail, id: 3)
      ]
      allow(FeeDetail).to receive(:where).and_return(fee_details)

      # 使用 stub 模拟 select_fee_detail 方法
      expect(work_order).to receive(:select_fee_detail).exactly(3).times

      work_order.select_fee_details(fee_detail_ids)
    end
  end

  # 状态检查方法测试
  describe "state check methods" do
    let(:reimbursement) { create(:reimbursement) }
    
    it "returns true for pending? when status is pending" do
      work_order = build(:audit_work_order, status: 'pending', reimbursement: reimbursement)
      expect(work_order.pending?).to be_truthy
    end

    it "returns true for processing? when status is processing" do
      work_order = build(:audit_work_order, status: 'processing', reimbursement: reimbursement)
      expect(work_order.processing?).to be_truthy
    end

    it "returns true for approved? when status is approved" do
      work_order = build(:audit_work_order, status: 'approved', reimbursement: reimbursement)
      expect(work_order.approved?).to be_truthy
    end

    it "returns true for rejected? when status is rejected" do
      work_order = build(:audit_work_order, status: 'rejected', reimbursement: reimbursement)
      expect(work_order.rejected?).to be_truthy
    end
  end
end