require 'rails_helper'

RSpec.describe WorkOrderFeeDetail, type: :model do
  # Associations
  describe "associations" do
    it { should belong_to(:work_order) }
    it { should belong_to(:fee_detail) }
  end

  # Validations
  describe "validations" do
    it { should validate_presence_of(:fee_detail_id) }
    it { should validate_presence_of(:work_order_id) }
    it { should validate_presence_of(:work_order_type) }
    
    it "validates uniqueness of fee_detail_id scoped to work_order_id and work_order_type" do
      # Create a record first
      work_order = create(:audit_work_order)
      fee_detail = create(:fee_detail, :with_reimbursement)
      WorkOrderFeeDetail.create!(
        work_order_id: work_order.id,
        work_order_type: work_order.type,
        fee_detail_id: fee_detail.id
      )
      
      # Try to create a duplicate
      duplicate = WorkOrderFeeDetail.new(
        work_order_id: work_order.id,
        work_order_type: work_order.type,
        fee_detail_id: fee_detail.id
      )
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:fee_detail_id]).to include("已经与此工单关联")
    end
  end

  # Scopes
  describe "scopes" do
    it "has a scope for filtering by work_order_type" do
      expect(WorkOrderFeeDetail).to respond_to(:by_work_order_type)
    end
    
    it "has a scope for filtering by fee_detail" do
      expect(WorkOrderFeeDetail).to respond_to(:by_fee_detail)
    end
    
    it "has a scope for filtering by work_order" do
      expect(WorkOrderFeeDetail).to respond_to(:by_work_order)
    end
  end

  # Methods
  describe "methods" do
    it "returns the associated work order" do
      work_order = create(:audit_work_order)
      fee_detail = create(:fee_detail, :with_reimbursement)
      work_order_fee_detail = WorkOrderFeeDetail.create!(
        work_order_id: work_order.id,
        work_order_type: work_order.type,
        fee_detail_id: fee_detail.id
      )
      
      expect(work_order_fee_detail.work_order).to eq(work_order)
    end
    
    it "returns the associated fee detail" do
      work_order = create(:audit_work_order)
      fee_detail = create(:fee_detail, :with_reimbursement)
      work_order_fee_detail = WorkOrderFeeDetail.create!(
        work_order_id: work_order.id,
        work_order_type: work_order.type,
        fee_detail_id: fee_detail.id
      )
      
      expect(work_order_fee_detail.fee_detail).to eq(fee_detail)
    end
  end
  
  # Callbacks
  describe "integration with fee detail status" do
    it "creates a valid association between work order and fee detail" do
      # Setup
      reimbursement = create(:reimbursement, status: "processing")
      fee_detail = create(:fee_detail, :with_reimbursement, verification_status: "pending")
      work_order = create(:audit_work_order, reimbursement: reimbursement, status: "approved")
      
      # Create the association
      work_order_fee_detail = WorkOrderFeeDetail.create!(
        work_order_id: work_order.id,
        work_order_type: work_order.type,
        fee_detail_id: fee_detail.id
      )
      
      # Verify the association was created
      expect(work_order_fee_detail).to be_persisted
      expect(work_order_fee_detail.work_order).to eq(work_order)
      expect(work_order_fee_detail.fee_detail).to eq(fee_detail)
    end
    
    it "updates fee detail status after destroy" do
      # Setup
      reimbursement = create(:reimbursement, status: "processing")
      fee_detail = create(:fee_detail, :with_reimbursement, verification_status: "pending")
      work_order = create(:audit_work_order, reimbursement: reimbursement, status: "approved")
      
      # Create the association
      association = WorkOrderFeeDetail.create!(
        work_order_id: work_order.id,
        work_order_type: work_order.type,
        fee_detail_id: fee_detail.id
      )
      
      # Expect the FeeDetailStatusService to be called
      expect_any_instance_of(FeeDetailStatusService).to receive(:update_status).once
      
      # Destroy the association
      association.destroy
    end
    
    it "allows multiple work orders to be associated with a fee detail" do
      # Setup
      reimbursement = create(:reimbursement, status: "processing")
      fee_detail = create(:fee_detail, :with_reimbursement, verification_status: "pending")
      
      # Create work orders
      work_order1 = create(:audit_work_order, reimbursement: reimbursement, status: "approved")
      work_order2 = create(:audit_work_order, reimbursement: reimbursement, status: "rejected")
      
      # Create associations
      work_order_fee_detail1 = WorkOrderFeeDetail.create!(
        work_order_id: work_order1.id,
        work_order_type: work_order1.type,
        fee_detail_id: fee_detail.id
      )
      
      work_order_fee_detail2 = WorkOrderFeeDetail.create!(
        work_order_id: work_order2.id,
        work_order_type: work_order2.type,
        fee_detail_id: fee_detail.id
      )
      
      # Verify the associations were created
      expect(work_order_fee_detail1).to be_persisted
      expect(work_order_fee_detail2).to be_persisted
      
      # Verify the fee detail has both work orders
      expect(fee_detail.work_order_fee_details.count).to eq(2)
    end
  end
end