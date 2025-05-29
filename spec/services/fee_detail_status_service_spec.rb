require 'rails_helper'

RSpec.describe FeeDetailStatusService, type: :service do
  let(:reimbursement) do
    Reimbursement.create!(
      invoice_number: "INV-001",
      document_name: "个人报销单",
      status: "processing",
      is_electronic: true
    )
  end
  
  let(:fee_detail) do
    FeeDetail.create!(
      document_number: reimbursement.invoice_number,
      fee_type: "交通费",
      amount: 100.0,
      verification_status: "pending"
    )
  end
  
  let(:audit_work_order) do
    AuditWorkOrder.create!(
      reimbursement: reimbursement,
      status: "pending",
      created_by: nil
    )
  end
  
  let(:communication_work_order) do
    CommunicationWorkOrder.create!(
      reimbursement: reimbursement,
      status: "pending",
      created_by: nil
    )
  end
  
  before do
    # Create work order fee detail associations
    WorkOrderFeeDetail.create!(
      work_order: audit_work_order,
      fee_detail: fee_detail,
      work_order_type: audit_work_order.type
    )
    
    WorkOrderFeeDetail.create!(
      work_order: communication_work_order,
      fee_detail: fee_detail,
      work_order_type: communication_work_order.type
    )
  end
  
  describe "#update_status" do
    it "sets fee detail status to pending when there are no work orders with a decision" do
      service = FeeDetailStatusService.new([fee_detail.id])
      service.update_status
      
      expect(fee_detail.reload.verification_status).to eq("pending")
    end
    
    it "sets fee detail status to verified when the latest work order is approved" do
      # First set the audit work order to rejected
      audit_work_order.update(status: "rejected")
      
      # Then set the communication work order to approved (this is newer)
      communication_work_order.update(status: "approved")
      
      # Update the timestamps to ensure communication_work_order is newer
      communication_work_order.update_column(:updated_at, Time.current)
      
      service = FeeDetailStatusService.new([fee_detail.id])
      service.update_status
      
      expect(fee_detail.reload.verification_status).to eq("verified")
    end
    
    it "sets fee detail status to problematic when the latest work order is rejected" do
      # First set the communication work order to approved
      communication_work_order.update(status: "approved")
      
      # Then set the audit work order to rejected (this is newer)
      audit_work_order.update(status: "rejected")
      
      # Update the timestamps to ensure audit_work_order is newer
      audit_work_order.update_column(:updated_at, Time.current)
      
      service = FeeDetailStatusService.new([fee_detail.id])
      service.update_status
      
      expect(fee_detail.reload.verification_status).to eq("problematic")
    end
  end
  
  describe "#update_status_for_work_order" do
    it "updates status for fee details associated with a specific work order" do
      # Set the audit work order to approved
      audit_work_order.update(status: "approved")
      
      service = FeeDetailStatusService.new
      service.update_status_for_work_order(audit_work_order)
      
      expect(fee_detail.reload.verification_status).to eq("verified")
    end
    
    it "follows the latest work order decides principle when updating for a specific work order" do
      # First set the communication work order to approved
      communication_work_order.update(status: "approved")
      
      # Update the timestamps to ensure communication_work_order is older
      communication_work_order.update_column(:updated_at, 1.day.ago)
      
      # Then set the audit work order to rejected
      audit_work_order.update(status: "rejected")
      
      # Update the timestamps to ensure audit_work_order is newer
      audit_work_order.update_column(:updated_at, Time.current)
      
      service = FeeDetailStatusService.new
      service.update_status_for_work_order(communication_work_order)
      
      # Even though we're updating for communication_work_order, the audit_work_order is newer
      # so the fee detail should still be problematic
      expect(fee_detail.reload.verification_status).to eq("problematic")
    end
  end
  
  describe "integration with work order status changes" do
    it "updates fee detail status when a work order status changes" do
      # Initially both work orders are pending, so fee detail should be pending
      expect(fee_detail.verification_status).to eq("pending")
      
      # Change the audit work order to approved
      audit_work_order.update(status: "approved")
      
      # The fee detail should now be verified
      expect(fee_detail.reload.verification_status).to eq("verified")
      
      # Change the communication work order to rejected (and make it newer)
      communication_work_order.update(status: "rejected")
      communication_work_order.update_column(:updated_at, Time.current)
      
      # The fee detail should now be problematic
      expect(fee_detail.reload.verification_status).to eq("problematic")
      
      # Change the audit work order to approved again (and make it newer)
      audit_work_order.update(status: "approved")
      audit_work_order.update_column(:updated_at, Time.current + 1.second)
      
      # Explicitly call the service to update the fee detail status
      FeeDetailStatusService.new([fee_detail.id]).update_status
      
      # The fee detail should now be verified again
      expect(fee_detail.reload.verification_status).to eq("verified")
    end
  end
end