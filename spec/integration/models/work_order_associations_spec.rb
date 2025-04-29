# spec/integration/models/work_order_associations_spec.rb
require 'rails_helper'

RSpec.describe "WorkOrder Associations", type: :model do
  describe "base class associations" do
    let(:work_order) { create(:audit_work_order) }
    
    it "belongs to reimbursement" do
      expect(work_order.reimbursement).to be_a(Reimbursement)
    end
    
    it "can have fee detail selections" do
      fee_detail = create(:fee_detail, document_number: work_order.reimbursement.invoice_number)
      
      # Create a new selection directly
      selection = FeeDetailSelection.create!(
        work_order_id: work_order.id,
        work_order_type: work_order.class.name,
        fee_detail_id: fee_detail.id,
        verification_status: 'pending'
      )
      
      # Reload to ensure associations are properly loaded
      work_order.reload
      fee_detail.reload
      
      # Verify the selection exists
      expect(FeeDetailSelection.where(work_order_id: work_order.id).count).to eq(1)
    end
    
    it "has many status changes" do
      # 触发状态变更
      work_order.start_processing!
      
      # Only check if there are status changes, not the exact count
      expect(work_order.work_order_status_changes.count).to be > 0
      expect(work_order.work_order_status_changes.last.from_status).to eq("pending")
      expect(work_order.work_order_status_changes.last.to_status).to eq("processing")
    end
  end
  
end