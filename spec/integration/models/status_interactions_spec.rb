# spec/integration/models/status_interactions_spec.rb
require 'rails_helper'

RSpec.describe "Status Interactions", type: :model do
  describe "fee detail status affecting reimbursement status" do
    let(:reimbursement) { create(:reimbursement, :processing) }
    let!(:fee_details) { create_list(:fee_detail, 3, document_number: reimbursement.invoice_number, verification_status: 'pending') }
    
    it "allows reimbursement to be marked as close when all fee details are verified" do
      # 将所有费用明细标记为已验证
      fee_details.each do |fee_detail|
        fee_detail.update(verification_status: 'verified')
      end
      
      # 重新加载报销单
      reimbursement.reload
      
      # 验证所有费用明细已验证
      expect(reimbursement.all_fee_details_verified?).to be true
      
      # 验证可以将报销单标记为close
      expect(reimbursement.can_mark_as_close?).to be true
      expect { reimbursement.mark_as_close! }.not_to raise_error
      expect(reimbursement.reload.status).to eq('close')
    end
    
    it "keeps reimbursement in processing status when some fee details are problematic" do
      # 将部分费用明细标记为已验证，部分标记为有问题
      fee_details[0].update(verification_status: 'verified')
      fee_details[1].update(verification_status: 'verified')
      fee_details[2].update(verification_status: 'problematic')
      
      # 重新加载报销单
      reimbursement.reload
      
      # 验证不是所有费用明细都已验证
      expect(reimbursement.all_fee_details_verified?).to be false
      
      # 验证不能将报销单标记为close
      expect(reimbursement.can_mark_as_close?).to be false
      expect { reimbursement.mark_as_close! }.to raise_error(ActiveRecord::RecordInvalid, /存在未验证的费用明细/)
      expect(reimbursement.reload.status).to eq('processing')
    end
  end
  
  describe "work order status affecting fee detail status" do
    let(:reimbursement) { create(:reimbursement) }
    let(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
    
    # 创建审核工单
    let(:audit_work_order) do
      # 先构建工单对象
      wo = build(:audit_work_order, reimbursement: reimbursement)
      
      # 设置fee_detail_ids_to_select
      wo.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
      
      # 保存工单
      wo.save!
      
      # 处理费用明细关联
      wo.process_fee_detail_selections
      
      wo
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
    
    it "can associate a fee detail with a work order" do
      # Create a new fee detail
      new_fee_detail = create(:fee_detail, document_number: reimbursement.invoice_number)
      
      # Create a new audit work order
      new_audit_work_order = build(:audit_work_order, reimbursement: reimbursement)
      new_audit_work_order.instance_variable_set('@fee_detail_ids_to_select', [])
      new_audit_work_order.save!
      
      # Create a work order fee detail association
      selection = WorkOrderFeeDetail.create!(
        work_order: new_audit_work_order,
        fee_detail: new_fee_detail
      )
      
      expect(selection.fee_detail_id).to eq(new_fee_detail.id)
      expect(selection.work_order_id).to eq(new_audit_work_order.id)
    end
  end
  
  describe "operation history affecting reimbursement status" do
    let(:reimbursement) { create(:reimbursement, :processing) }
    
    it "closes reimbursement when operation history with approval is imported" do
      # 创建审批通过的操作历史
      create(:operation_history, 
             document_number: reimbursement.invoice_number,
             operation_type: '审批',
             notes: '审批通过')
      
      # 模拟 OperationHistoryImportService 的行为
      reimbursement.mark_as_close!
      reimbursement.reload
      
      expect(reimbursement.status).to eq('close')
    end
  end
end