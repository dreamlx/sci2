# spec/models/fee_detail_spec.rb
require 'rails_helper'

RSpec.describe FeeDetail, type: :model do
  # 验证测试（不依赖其他模型）
  describe "validations" do
    it { should validate_presence_of(:document_number) }
    it { should validate_presence_of(:fee_type) }
    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }
    it { should validate_presence_of(:verification_status) }
    it { should validate_inclusion_of(:verification_status).in_array(%w[pending problematic verified]) }
  end
  
  # 关联方法测试（使用 respond_to 而不是实际测试关联）
  describe "association methods" do
    it { should respond_to(:reimbursement) }
    it { should respond_to(:fee_detail_selections) }
    it { should respond_to(:work_orders) }
  end
  
  # 常量测试
  describe "constants" do
    it "defines verification status constants" do
      expect(FeeDetail::VERIFICATION_STATUS_PENDING).to eq('pending')
      expect(FeeDetail::VERIFICATION_STATUS_PROBLEMATIC).to eq('problematic')
      expect(FeeDetail::VERIFICATION_STATUS_VERIFIED).to eq('verified')
      expect(FeeDetail::VERIFICATION_STATUSES).to eq(['pending', 'problematic', 'verified'])
    end
  end
  
  # 状态检查方法测试
  describe "state check methods" do
    it "returns true for verified? when verification_status is verified" do
      fee_detail = build(:fee_detail, verification_status: 'verified')
      expect(fee_detail.verified?).to be_truthy
    end
    
    it "returns true for problematic? when verification_status is problematic" do
      fee_detail = build(:fee_detail, verification_status: 'problematic')
      expect(fee_detail.problematic?).to be_truthy
    end
    
    it "returns true for pending? when verification_status is pending" do
      fee_detail = build(:fee_detail, verification_status: 'pending')
      expect(fee_detail.pending?).to be_truthy
    end
  end
  
  # 业务方法测试
  describe "#mark_as_verified" do
    let(:fee_detail) { build(:fee_detail, verification_status: 'pending') }
    
    it "updates verification_status to verified" do
      expect(fee_detail).to receive(:update).with(verification_status: 'verified')
      fee_detail.mark_as_verified
    end
  end
  
  describe "#mark_as_problematic" do
    let(:fee_detail) { build(:fee_detail, verification_status: 'pending') }
    
    it "updates verification_status to problematic" do
      expect(fee_detail).to receive(:update).with(verification_status: 'problematic')
      fee_detail.mark_as_problematic
    end
  end
  
  # 回调测试
  describe "callbacks" do
    describe "update_reimbursement_status" do
      let(:reimbursement) { instance_double("Reimbursement") }
      let(:fee_detail) { build(:fee_detail, verification_status: 'pending') }
      
      before do
        allow(fee_detail).to receive(:reimbursement).and_return(reimbursement)
        allow(reimbursement).to receive(:reload)
        # 模拟 saved_change_to_verification_status? 返回 true
        allow(fee_detail).to receive(:saved_change_to_verification_status?).and_return(true)
        # 模拟 verification_status_before_last_save
        allow(fee_detail).to receive(:verification_status_before_last_save).and_return('pending')
      end
      
      context "when status changes to verified" do
        before do
          fee_detail.verification_status = 'verified'
        end
        
        it "calls update_status_based_on_fee_details! on reimbursement" do
          expect(reimbursement).to receive(:update_status_based_on_fee_details!)
          fee_detail.send(:update_reimbursement_status)
        end
      end
      
      context "when status changes from verified to problematic" do
        before do
          fee_detail.verification_status = 'problematic'
          allow(fee_detail).to receive(:verification_status_before_last_save).and_return('verified')
          allow(reimbursement).to receive(:waiting_completion?).and_return(true)
        end
        
        it "calls start_processing! on reimbursement if it's in waiting_completion state" do
          expect(reimbursement).to receive(:start_processing!)
          fee_detail.send(:update_reimbursement_status)
        end
      end
      
      context "when reimbursement is not in waiting_completion state" do
        before do
          fee_detail.verification_status = 'problematic'
          allow(fee_detail).to receive(:verification_status_before_last_save).and_return('verified')
          allow(reimbursement).to receive(:waiting_completion?).and_return(false)
        end
        
        it "doesn't call start_processing! on reimbursement" do
          expect(reimbursement).not_to receive(:start_processing!)
          fee_detail.send(:update_reimbursement_status)
        end
      end
    end
  end
end