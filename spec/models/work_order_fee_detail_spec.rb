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
end