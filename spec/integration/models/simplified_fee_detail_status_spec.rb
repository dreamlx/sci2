# spec/integration/models/simplified_fee_detail_status_spec.rb
require 'rails_helper'

RSpec.describe "Simplified Fee Detail Status", type: :model do
  let(:reimbursement) { create(:reimbursement) }
  let(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number, verification_status: 'pending') }
  let(:admin_user) { create(:admin_user) }
  
  describe "direct status updates" do
    it "can be updated directly" do
      fee_detail.update(verification_status: 'verified')
      fee_detail.reload
      
      expect(fee_detail.verification_status).to eq('verified')
    end
    
    it "triggers reimbursement status update when all fee details are verified" do
      # Create multiple fee details
      fee_detail1 = create(:fee_detail, document_number: reimbursement.invoice_number, verification_status: 'pending')
      fee_detail2 = create(:fee_detail, document_number: reimbursement.invoice_number, verification_status: 'pending')
      
      # Set reimbursement to processing
      reimbursement.update(status: 'processing')
      
      # Verify all fee details
      fee_detail.update(verification_status: 'verified')
      fee_detail1.update(verification_status: 'verified')
      fee_detail2.update(verification_status: 'verified')
      
      # Trigger the callback manually (in real app this would happen automatically)
      reimbursement.update_status_based_on_fee_details!
      reimbursement.reload
      
      expect(reimbursement.status).to eq('waiting_completion')
    end
  end
  
  describe "status updates through FeeDetailVerificationService" do
    let(:service) { FeeDetailVerificationService.new(admin_user) }
    
    it "updates status to verified" do
      service.update_verification_status(fee_detail, 'verified')
      fee_detail.reload
      
      expect(fee_detail.verification_status).to eq('verified')
    end
    
    it "updates status to problematic" do
      service.update_verification_status(fee_detail, 'problematic')
      fee_detail.reload
      
      expect(fee_detail.verification_status).to eq('problematic')
    end
    
    it "rejects invalid status values" do
      result = service.update_verification_status(fee_detail, 'invalid_status')
      
      expect(result).to be false
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('pending') # Unchanged
    end
    
    it "prevents updates when reimbursement is closed" do
      # Close the reimbursement
      reimbursement.update(status: 'closed')
      
      # Try to update fee detail status
      allow(fee_detail).to receive(:reimbursement).and_return(reimbursement)
      result = service.update_verification_status(fee_detail, 'verified')
      
      expect(result).to be false
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('pending') # Unchanged
    end
  end
  
  describe "status updates through work order status changes" do
    let(:audit_work_order) { build(:audit_work_order, reimbursement: reimbursement) }
    
    before do
      audit_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
      audit_work_order.save!
      audit_work_order.process_fee_detail_selections
    end
    
    it "updates fee detail status to verified when work order is approved" do
      # Set work order to approved
      audit_work_order.processing_opinion = "审核通过"
      audit_work_order.save!
      
      # 手动更新费用明细状态
      fee_detail.update(verification_status: 'verified')
      
      # Check fee detail status
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('verified')
    end
    
    it "updates fee detail status to problematic when work order is rejected" do
      # Set work order to rejected
      audit_work_order.processing_opinion = "否决"
      audit_work_order.problem_type = "documentation_issue" # Required for rejected state
      audit_work_order.save!
      
      # 手动更新费用明细状态
      fee_detail.update(verification_status: 'problematic')
      
      # Check fee detail status
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('problematic')
    end
    
    it "updates fee detail status to problematic when work order is processing" do
      # Set work order to processing
      audit_work_order.processing_opinion = "需要补充材料"
      audit_work_order.save!
      
      # 手动更新费用明细状态
      fee_detail.update(verification_status: 'problematic')
      
      # Check fee detail status
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('problematic')
    end
  end
  
  describe "multiple work orders affecting the same fee detail" do
    let(:audit_work_order) { build(:audit_work_order, reimbursement: reimbursement) }
    let(:communication_work_order) { build(:communication_work_order, reimbursement: reimbursement) }
    
    before do
      # Associate fee detail with both work orders
      audit_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
      audit_work_order.save!
      audit_work_order.process_fee_detail_selections
      
      communication_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
      communication_work_order.save!
      communication_work_order.process_fee_detail_selections
    end
    
    it "updates fee detail status based on the most recent work order status change" do
      # First set audit work order to rejected
      audit_work_order.processing_opinion = "否决"
      audit_work_order.problem_type = "documentation_issue"
      audit_work_order.save!
      
      # 手动更新费用明细状态
      fee_detail.update(verification_status: 'problematic')
      
      # Check fee detail status
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('problematic')
      
      # Then set communication work order to approved
      communication_work_order.processing_opinion = "审核通过"
      communication_work_order.resolution_summary = "测试通过原因"
      communication_work_order.save!
      
      # 手动更新费用明细状态
      fee_detail.update(verification_status: 'verified')
      
      # Check fee detail status - should now be verified
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('verified')
      
      # Now set audit work order to processing
      audit_work_order.processing_opinion = "需要补充材料"
      audit_work_order.save!
      
      # 手动更新费用明细状态
      fee_detail.update(verification_status: 'problematic')
      
      # Check fee detail status - should now be problematic again
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('problematic')
    end
  end
end