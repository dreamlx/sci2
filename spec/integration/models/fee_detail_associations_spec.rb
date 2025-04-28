# spec/integration/models/fee_detail_associations_spec.rb
require 'rails_helper'

RSpec.describe "FeeDetail Associations", type: :model do
  let(:reimbursement) { create(:reimbursement) }
  let(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  
  it "belongs to reimbursement" do
    expect(fee_detail.reimbursement).to eq(reimbursement)
  end
  
  it "has many fee detail selections" do
    audit_work_order = create(:audit_work_order, reimbursement: reimbursement)
    selection = create(:fee_detail_selection, work_order: audit_work_order, fee_detail: fee_detail)
    
    # Reload to ensure associations are properly loaded
    fee_detail.reload
    
    expect(fee_detail.fee_detail_selections).to include(selection)
  end
  
  it "can be associated with audit work orders" do
    audit_work_order = create(:audit_work_order, reimbursement: reimbursement)
    
    # Create fee detail selection
    selection = create(:fee_detail_selection, work_order: audit_work_order, fee_detail: fee_detail)
    
    # Reload to ensure associations are properly loaded
    fee_detail.reload
    
    # Check that we have a fee detail selection
    expect(fee_detail.fee_detail_selections.count).to eq(1)
  end
end