# spec/integration/models/fee_detail_work_order_associations_spec.rb
require 'rails_helper'

RSpec.describe "FeeDetail Work Order Associations", type: :model do
  let(:reimbursement) { create(:reimbursement) }
  let(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  let(:admin_user) { create(:admin_user) }
  
  describe "accessing related work orders" do
    let(:audit_work_order) { build(:audit_work_order, reimbursement: reimbursement, creator: admin_user) }
    let(:communication_work_order) { build(:communication_work_order, reimbursement: reimbursement, creator: admin_user) }
    
    before do
      # Associate fee detail with audit work order
      audit_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
      audit_work_order.save!
      audit_work_order.process_fee_detail_selections
      
      # Associate fee detail with communication work order
      communication_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
      communication_work_order.save!
      communication_work_order.process_fee_detail_selections
    end
    
    it "can access all related work orders" do
      # Reload fee detail to ensure associations are loaded
      fee_detail.reload
      
      # Debug information
      puts "Fee detail ID: #{fee_detail.id}"
      puts "Audit work order ID: #{audit_work_order.id}"
      puts "Communication work order ID: #{communication_work_order.id}"
      puts "Fee detail selections count: #{FeeDetailSelection.count}"
      puts "Fee detail selections for fee detail: #{FeeDetailSelection.where(fee_detail_id: fee_detail.id).count}"
      puts "Fee detail selections for audit work order: #{FeeDetailSelection.where(work_order_id: audit_work_order.id, work_order_type: 'AuditWorkOrder').count}"
      puts "Fee detail selections for communication work order: #{FeeDetailSelection.where(work_order_id: communication_work_order.id, work_order_type: 'CommunicationWorkOrder').count}"
      
      # Check that fee detail is associated with both work orders
      work_orders = fee_detail.work_orders
      puts "Work orders count: #{work_orders.count}"
      puts "Work order IDs: #{work_orders.pluck(:id).inspect}"
      
      expect(work_orders.count).to eq(2)
      expect(work_orders.pluck(:id)).to include(audit_work_order.id)
      expect(work_orders.pluck(:id)).to include(communication_work_order.id)
    end
    
    it "can access audit work orders specifically" do
      fee_detail.reload
      
      expect(fee_detail.audit_work_orders.count).to eq(1)
      expect(fee_detail.audit_work_orders.first).to eq(audit_work_order)
    end
    
    it "can access communication work orders specifically" do
      fee_detail.reload
      
      expect(fee_detail.communication_work_orders.count).to eq(1)
      expect(fee_detail.communication_work_orders.first).to eq(communication_work_order)
    end
  end
  
  describe "accessing related fee details from work orders" do
    let(:audit_work_order) { build(:audit_work_order, reimbursement: reimbursement, creator: admin_user) }
    let(:fee_detail2) { create(:fee_detail, document_number: reimbursement.invoice_number) }
    
    before do
      # Associate multiple fee details with work order
      audit_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id, fee_detail2.id])
      audit_work_order.save!
      audit_work_order.process_fee_detail_selections
    end
    
    it "can access all related fee details using the associated_fee_details method" do
      # Use the custom method we added
      related_fee_details = audit_work_order.associated_fee_details
      
      expect(related_fee_details.count).to eq(2)
      expect(related_fee_details).to include(fee_detail)
      expect(related_fee_details).to include(fee_detail2)
    end
    
    it "updates all related fee details when work order status changes" do
      # Change work order status
      audit_work_order.processing_opinion = "审核通过"
      audit_work_order.save!
      
      # Reload fee details
      fee_detail.reload
      fee_detail2.reload
      
      # Both fee details should be verified
      expect(fee_detail.verification_status).to eq("verified")
      expect(fee_detail2.verification_status).to eq("verified")
    end
  end
end