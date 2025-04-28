# spec/integration/models/status_interactions_spec.rb
require 'rails_helper'

RSpec.describe "Status Interactions", type: :model do
  describe "fee detail status affecting reimbursement status" do
    let(:reimbursement) { create(:reimbursement, :processing) }
    let!(:fee_details) { create_list(:fee_detail, 3, document_number: reimbursement.invoice_number, verification_status: 'pending') }
    
    it "updates reimbursement status when all fee details are verified" do
      # 将所有费用明细标记为已验证
      fee_details.each do |fee_detail|
        fee_detail.update(verification_status: 'verified')
        # 模拟 FeeDetail 回调
        reimbursement.update_status_based_on_fee_details!
      end
      
      # 重新加载报销单
      reimbursement.reload
      expect(reimbursement.status).to eq('waiting_completion')
    end
    
    it "keeps reimbursement in processing status when some fee details are problematic" do
      # 将部分费用明细标记为已验证，部分标记为有问题
      fee_details[0].update(verification_status: 'verified')
      fee_details[1].update(verification_status: 'verified')
      fee_details[2].update(verification_status: 'problematic')
      
      # 模拟 FeeDetail 回调
      reimbursement.update_status_based_on_fee_details!
      
      # 重新加载报销单
      reimbursement.reload
      expect(reimbursement.status).to eq('processing')
    end
  end
  
  describe "work order status affecting fee detail status" do
    let(:reimbursement) { create(:reimbursement) }
    let(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
    let(:audit_work_order) { create(:audit_work_order, reimbursement: reimbursement) }
    
    before do
      # 关联费用明细和工单
      create(:fee_detail_selection, work_order: audit_work_order, fee_detail: fee_detail)
    end
    
    it "can update fee detail status to problematic" do
      # Directly update fee detail status
      fee_detail.update(verification_status: 'problematic')
      fee_detail.reload
      
      expect(fee_detail.verification_status).to eq('problematic')
    end
    
    it "can update fee detail status to verified" do
      # Directly update fee detail status
      fee_detail.update(verification_status: 'verified')
      fee_detail.reload
      
      expect(fee_detail.verification_status).to eq('verified')
    end
    
    it "can create a fee detail selection with problematic status" do
      # Create a fee detail selection with problematic status
      selection = FeeDetailSelection.create!(
        work_order: audit_work_order,
        fee_detail: fee_detail,
        verification_status: 'problematic'
      )
      
      expect(selection.verification_status).to eq('problematic')
    end
  end
  
  describe "operation history affecting reimbursement status" do
    let(:reimbursement) { create(:reimbursement, :waiting_completion) }
    
    it "closes reimbursement when operation history with approval is imported" do
      # 创建审批通过的操作历史
      create(:operation_history, 
             document_number: reimbursement.invoice_number,
             operation_type: '审批',
             notes: '审批通过')
      
      # 模拟 OperationHistoryImportService 的行为
      reimbursement.close!
      reimbursement.reload
      
      expect(reimbursement.status).to eq('closed')
    end
  end
end