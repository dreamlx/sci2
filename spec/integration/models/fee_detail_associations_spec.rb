# spec/integration/models/fee_detail_associations_spec.rb
require 'rails_helper'

RSpec.describe "FeeDetail Associations", type: :model do
  let(:reimbursement) { create(:reimbursement) }
  let(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  
  it "belongs to reimbursement" do
    expect(fee_detail.reimbursement).to eq(reimbursement)
  end
  
  it "has many fee detail selections" do
    # 先构建工单对象
    audit_work_order = build(:audit_work_order, reimbursement: reimbursement)
    
    # 设置fee_detail_ids_to_select
    audit_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
    
    # 保存工单
    audit_work_order.save!
    
    # 处理费用明细关联
    audit_work_order.process_fee_detail_selections
    
    # 获取创建的fee_detail_selection
    selection = FeeDetailSelection.find_by(work_order: audit_work_order, fee_detail: fee_detail)
    
    # Reload to ensure associations are properly loaded
    fee_detail.reload
    
    expect(fee_detail.fee_detail_selections).to include(selection)
  end
  
  it "can be associated with audit work orders" do
    # 先构建工单对象
    audit_work_order = build(:audit_work_order, reimbursement: reimbursement)
    
    # 设置fee_detail_ids_to_select
    audit_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
    
    # 保存工单
    audit_work_order.save!
    
    # 处理费用明细关联
    audit_work_order.process_fee_detail_selections
    
    # 获取创建的fee_detail_selection
    selection = FeeDetailSelection.find_by(work_order: audit_work_order, fee_detail: fee_detail)
    
    # Reload to ensure associations are properly loaded
    fee_detail.reload
    
    # Check that we have a fee detail selection
    expect(fee_detail.fee_detail_selections.count).to eq(1)
  end
end