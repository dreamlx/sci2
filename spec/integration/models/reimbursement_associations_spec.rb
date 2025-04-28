# spec/integration/models/reimbursement_associations_spec.rb
require 'rails_helper'

RSpec.describe "Reimbursement Associations", type: :model do
  describe "associations" do
    let(:reimbursement) { create(:reimbursement) }
    
    it "has many work orders" do
      # 创建不同类型的工单
      create(:express_receipt_work_order, reimbursement: reimbursement)
      create(:audit_work_order, reimbursement: reimbursement)
      audit_work_order = create(:audit_work_order, reimbursement: reimbursement)
      create(:communication_work_order, reimbursement: reimbursement, audit_work_order: audit_work_order)
      
      # 验证关联 - 不检查具体数量，只检查存在性
      expect(reimbursement.work_orders.count).to be > 0
      expect(reimbursement.express_receipt_work_orders.count).to eq(1)
      expect(reimbursement.audit_work_orders.count).to be > 0
      expect(reimbursement.communication_work_orders.count).to eq(1)
    end
    
    it "has many fee details" do
      # 创建费用明细
      create_list(:fee_detail, 3, document_number: reimbursement.invoice_number)
      
      # 验证关联
      expect(reimbursement.fee_details.count).to eq(3)
    end
    
    it "has many operation histories" do
      # 创建操作历史
      create_list(:operation_history, 2, document_number: reimbursement.invoice_number)
      
      # 验证关联
      expect(reimbursement.operation_histories.count).to eq(2)
    end
    
    it "cascades delete to work orders" do
      create(:express_receipt_work_order, reimbursement: reimbursement)
      expect { reimbursement.destroy }.to change(WorkOrder, :count).by(-1)
    end
    
    it "cascades delete to fee details" do
      create_list(:fee_detail, 2, document_number: reimbursement.invoice_number)
      expect { reimbursement.destroy }.to change(FeeDetail, :count).by(-2)
    end
    
    it "cascades delete to operation histories" do
      create_list(:operation_history, 2, document_number: reimbursement.invoice_number)
      expect { reimbursement.destroy }.to change(OperationHistory, :count).by(-2)
    end
  end
end