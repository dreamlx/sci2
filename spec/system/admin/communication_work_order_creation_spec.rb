require 'rails_helper'

RSpec.describe "Communication Work Order Creation", type: :system do
  let(:admin_user) { create(:admin_user) }
  let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001', applicant: '测试用户1') }
  let!(:fee_detail) { create(:fee_detail, document_number: 'R202501001', fee_type: '交通费', amount: 100.00) }
  
  before do
    login_as(admin_user, scope: :admin_user)
  end

  it "creates a communication work order with fee details" do
    # Create the communication work order directly
    communication_work_order = CommunicationWorkOrder.new(
      reimbursement: reimbursement,
      status: 'pending',
      initiator_role: '申请人',
      communication_method: '电话',
      remark: '测试沟通备注',
      creator: admin_user
    )
    
    # Set fee_detail_ids_to_select before saving
    communication_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
    
    # Save the communication work order
    expect(communication_work_order.save).to be true
    
    # Process fee detail selections
    communication_work_order.process_fee_detail_selections
    
    # Check that the communication work order has the correct attributes
    expect(communication_work_order.reimbursement_id).to eq(reimbursement.id)
    expect(communication_work_order.initiator_role).to eq('申请人')
    expect(communication_work_order.communication_method).to eq('电话')
    expect(communication_work_order.remark).to eq('测试沟通备注')
    
    # Check that the fee detail is associated with the communication work order
    expect(communication_work_order.fee_details.reload).to include(fee_detail)
    
    # Add a communication record
    communication_record = communication_work_order.communication_records.create!(
      content: '测试沟通内容',
      communicator_role: '财务人员',
      communicator_name: admin_user.email,
      communication_method: '电话',
      recorded_at: Time.current
    )
    
    # Check that the communication record was created
    expect(communication_work_order.communication_records.count).to eq(1)
    expect(communication_work_order.communication_records.first.content).to eq('测试沟通内容')
  end
end