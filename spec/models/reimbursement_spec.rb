# spec/models/reimbursement_spec.rb
require 'rails_helper'

RSpec.describe Reimbursement, type: :model do
  # 验证测试（不依赖其他模型）
  describe "validations" do
    it { should validate_presence_of(:invoice_number) }
    # 为 uniqueness 测试提供一个有效的记录
    it do
      create(:reimbursement, invoice_number: "R202501001")
      should validate_uniqueness_of(:invoice_number)
    end
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[pending processing waiting_completion closed]) }
    it { should validate_inclusion_of(:is_electronic).in_array([true, false]) }
  end

  # 关联方法测试（使用 respond_to 而不是实际测试关联）
  describe "association methods" do
    it { should respond_to(:work_orders) }
    it { should respond_to(:audit_work_orders) }
    it { should respond_to(:communication_work_orders) }
    it { should respond_to(:express_receipt_work_orders) }
    it { should respond_to(:fee_details) }
    it { should respond_to(:operation_histories) }
  end

  # 状态机测试
  describe "state machine" do
    let(:reimbursement) { create(:reimbursement) }

    context "when in pending state" do
      it "can transition to processing" do
        expect(reimbursement.status).to eq("pending")
        expect(reimbursement.start_processing!).to be_truthy
        expect(reimbursement.status).to eq("processing")
      end
    end

    context "when in processing state" do
      let(:reimbursement) { create(:reimbursement, :processing) }

      it "can transition to waiting_completion if all fee details are verified" do
        # 使用 stub 模拟 all_fee_details_verified? 方法
        allow(reimbursement).to receive(:all_fee_details_verified?).and_return(true)
        expect(reimbursement.mark_waiting_completion!).to be_truthy
        expect(reimbursement.status).to eq("waiting_completion")
      end

      it "cannot transition to waiting_completion if not all fee details are verified" do
        # 使用 stub 模拟 all_fee_details_verified? 方法
        allow(reimbursement).to receive(:all_fee_details_verified?).and_return(false)
        expect { reimbursement.mark_waiting_completion! }.to raise_error(StateMachines::InvalidTransition)
        expect(reimbursement.status).to eq("processing")
      end
    end

    context "when in waiting_completion state" do
      let(:reimbursement) { create(:reimbursement, :waiting_completion) }

      it "can transition to closed" do
        expect(reimbursement.close!).to be_truthy
        expect(reimbursement.status).to eq("closed")
      end

      it "can transition back to processing" do
        expect(reimbursement.start_processing!).to be_truthy
        expect(reimbursement.status).to eq("processing")
      end
    end
  end

  # 业务方法测试
  describe "#mark_as_received" do
    let(:reimbursement) { create(:reimbursement) }

    it "updates receipt_status and receipt_date" do
      receipt_date = Time.current
      reimbursement.mark_as_received(receipt_date)
      expect(reimbursement.receipt_status).to eq("received")
      expect(reimbursement.receipt_date).to be_within(1.second).of(receipt_date)
    end

    it "transitions to processing if in pending state" do
      expect(reimbursement.status).to eq("pending")
      reimbursement.mark_as_received
      expect(reimbursement.status).to eq("processing")
    end
  end

  describe "#all_fee_details_verified?" do
    let(:reimbursement) { create(:reimbursement) }

    context "when all fee details are verified" do
      it "returns true when all fee details are verified" do
        # 使用 mock 模拟 fee_details 关联和 loaded? 方法
        fee_details = double("FeeDetailsCollection")
        allow(fee_details).to receive(:loaded?).and_return(true)
        allow(fee_details).to receive(:present?).and_return(true)
        allow(fee_details).to receive(:all?).and_return(true)
        allow(reimbursement).to receive(:fee_details).and_return(fee_details)

        expect(reimbursement.all_fee_details_verified?).to be_truthy
      end
    end

    context "when some fee details are not verified" do
      it "returns false" do
        # 使用 mock 模拟 fee_details 关联和 loaded? 方法
        fee_details = double("FeeDetailsCollection")
        allow(fee_details).to receive(:loaded?).and_return(true)
        allow(fee_details).to receive(:present?).and_return(true)
        allow(fee_details).to receive(:all?).and_return(false)
        allow(reimbursement).to receive(:fee_details).and_return(fee_details)

        expect(reimbursement.all_fee_details_verified?).to be_falsey
      end
    end

    context "when there are no fee details" do
      it "returns false" do
        # 使用 mock 模拟空的 fee_details 关联和 loaded? 方法
        empty_details = double("EmptyFeeDetailsCollection")
        allow(empty_details).to receive(:loaded?).and_return(true)
        allow(empty_details).to receive(:present?).and_return(false)
        allow(reimbursement).to receive(:fee_details).and_return(empty_details)

        expect(reimbursement.all_fee_details_verified?).to be_falsey
      end
    end
  end

  describe "#update_status_based_on_fee_details!" do
    context "when processing and all fee details verified" do
      let(:reimbursement) { create(:reimbursement, :processing) }

      it "calls mark_waiting_completion!" do
        allow(reimbursement).to receive(:all_fee_details_verified?).and_return(true)
        expect(reimbursement).to receive(:mark_waiting_completion!)
        reimbursement.update_status_based_on_fee_details!
      end
    end

    context "when not processing" do
      # 使用默认 factory，默认状态是 pending
      let(:reimbursement) { create(:reimbursement) }

      it "does not call mark_waiting_completion!" do
        allow(reimbursement).to receive(:all_fee_details_verified?).and_return(true)
        expect(reimbursement).not_to receive(:mark_waiting_completion!)
        reimbursement.update_status_based_on_fee_details!
      end
    end
  end
end