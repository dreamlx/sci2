# spec/integration/models/fee_detail_associations_spec.rb
require 'rails_helper'

RSpec.describe "FeeDetail Associations", type: :model do
  let(:reimbursement) { create(:reimbursement) }
  let(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  
  it "belongs to reimbursement" do
    expect(fee_detail.reimbursement).to eq(reimbursement)
  end
  
  it "has many work order fee details" do
    # 先构建工单对象
    audit_work_order = build(:audit_work_order, reimbursement: reimbursement)
    
    # 保存工单
    audit_work_order.save!
    
    # 直接创建关联
    work_order_fee_detail = WorkOrderFeeDetail.create!(
      work_order: audit_work_order,
      fee_detail: fee_detail
    )
    
    # Reload to ensure associations are properly loaded
    fee_detail.reload
    
    expect(fee_detail.work_order_fee_details).to include(work_order_fee_detail)
  end
  
  it "can be associated with audit work orders" do
    # 先构建工单对象
    audit_work_order = build(:audit_work_order, reimbursement: reimbursement)
    
    # 保存工单
    audit_work_order.save!
    
    # 直接创建关联
    WorkOrderFeeDetail.create!(
      work_order: audit_work_order,
      fee_detail: fee_detail
    )
    
    # Reload to ensure associations are properly loaded
    fee_detail.reload
    
    # Check that we have a work order fee detail
    expect(fee_detail.work_orders).to include(audit_work_order)
  end
end