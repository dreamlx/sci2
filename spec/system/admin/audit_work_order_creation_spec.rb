require 'rails_helper'

RSpec.describe "Audit Work Order Creation", type: :system do
  let(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001', applicant: '测试用户1') }
  let!(:fee_detail) { create(:fee_detail, document_number: 'R202501001', fee_type: '交通费', amount: 100.00) }
  
  before do
    login_as(admin_user, scope: :admin_user)
  end

  it "creates an audit work order with fee details" do
    # Create the audit work order directly
    audit_work_order = AuditWorkOrder.new(
      reimbursement: reimbursement,
      status: 'pending',
      problem_type: '发票问题',
      remark: '测试备注',
      creator: admin_user
    )
    
    # Set fee_detail_ids_to_select before saving
    audit_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
    
    # Save the audit work order
    expect(audit_work_order.save).to be true
    
    # Process fee detail selections
    audit_work_order.process_fee_detail_selections
    
    # Check that the audit work order has the correct attributes
    expect(audit_work_order.reimbursement_id).to eq(reimbursement.id)
    expect(audit_work_order.problem_type).to eq('发票问题')
    expect(audit_work_order.remark).to eq('测试备注')
    
    # Check that the fee detail is associated with the audit work order
    expect(audit_work_order.fee_details.reload).to include(fee_detail)
  end
end