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
  describe "#update_reimbursement_status" do
    let(:reimbursement) { create(:reimbursement) }
    let(:fee_detail) { create(:fee_detail, reimbursement: reimbursement, verification_status: 'pending') }
    
    context "when fee detail is verified" do
      it "updates reimbursement status to waiting_completion if all fee details are verified" do
        # 创建另一个 fee_detail 并设置为 verified
        create(:fee_detail, reimbursement: reimbursement, verification_status: 'verified')
        
        # 设置当前 fee_detail 为 verified
        fee_detail.update(verification_status: 'verified')
        
        # 检查 reimbursement 状态是否变为 waiting_completion
        expect(reimbursement.reload.status).to eq('waiting_completion')
      end
      
      it "does not update reimbursement status if not all fee details are verified" do
        # 设置 reimbursement 状态为 processing
        reimbursement.update(status: 'processing')
        
        # 创建另一个未验证的 fee_detail
        create(:fee_detail, reimbursement: reimbursement, verification_status: 'pending')
        
        # 设置当前 fee_detail 为 verified
        fee_detail.update(verification_status: 'verified')
        
        # 检查 reimbursement 状态是否保持为 processing
        expect(reimbursement.reload.status).to eq('processing')
      end
    end
    
    context "when fee detail is marked as problematic" do
      it "updates reimbursement status to processing if it was waiting_completion" do
        # 创建另一个 fee_detail 并设置为 verified
        create(:fee_detail, reimbursement: reimbursement, verification_status: 'verified')
        
        # 设置当前 fee_detail 为 verified，使 reimbursement 状态变为 waiting_completion
        fee_detail.update(verification_status: 'verified')
        expect(reimbursement.reload.status).to eq('waiting_completion')
        
        # 设置当前 fee_detail 为 problematic
        fee_detail.update(verification_status: 'problematic')
        
        # 检查 reimbursement 状态是否变为 processing
        expect(reimbursement.reload.status).to eq('processing')
      end
    end
    
    context "when fee detail is marked as pending" do
      it "updates reimbursement status to processing if it was waiting_completion" do
        # 创建另一个 fee_detail 并设置为 verified
        create(:fee_detail, reimbursement: reimbursement, verification_status: 'verified')
        
        # 设置当前 fee_detail 为 verified，使 reimbursement 状态变为 waiting_completion
        fee_detail.update(verification_status: 'verified')
        expect(reimbursement.reload.status).to eq('waiting_completion')
        
        # 设置当前 fee_detail 为 pending
        fee_detail.update(verification_status: 'pending')
        
        # 检查 reimbursement 状态是否变为 processing
        expect(reimbursement.reload.status).to eq('processing')
      end
    end
  end
  
  # 回调测试
  describe "callbacks" do
    describe "after_commit" do
      let(:reimbursement) { create(:reimbursement) }
      let(:fee_detail) { create(:fee_detail, reimbursement: reimbursement, verification_status: 'pending') }
      
      it "calls update_reimbursement_status after verification_status change" do
        # 模拟 update_reimbursement_status 方法
        allow(fee_detail).to receive(:update_reimbursement_status)
        
        # 更改 verification_status
        fee_detail.update(verification_status: 'verified')
        
        # 验证 update_reimbursement_status 方法被调用
        expect(fee_detail).to have_received(:update_reimbursement_status)
      end
    end
  end
end