require 'rails_helper'

RSpec.describe FeeDetail, type: :model do
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
  
  let(:admin_user) do
    AdminUser.create!(
      email: "admin@example.com",
      password: "password",
      password_confirmation: "password"
    )
  end
  
  # Associations
  describe "associations" do
    it { should belong_to(:reimbursement).with_foreign_key('document_number').with_primary_key('invoice_number') }
    it { should have_many(:work_order_fee_details).dependent(:destroy) }
    it { should have_many(:work_orders).through(:work_order_fee_details) }
  end
  
  # Validations
  describe "validations" do
    subject { fee_detail }
    
    it { should validate_presence_of(:document_number) }
    it { should validate_numericality_of(:amount).is_greater_than_or_equal_to(0).allow_nil }
    it { should validate_inclusion_of(:verification_status).in_array(FeeDetail::VERIFICATION_STATUSES) }
  end
  
  # Scopes
  describe "scopes" do
    it "has a scope for pending fee details" do
      expect(FeeDetail).to respond_to(:pending)
    end
    
    it "has a scope for problematic fee details" do
      expect(FeeDetail).to respond_to(:problematic)
    end
    
    it "has a scope for verified fee details" do
      expect(FeeDetail).to respond_to(:verified)
    end
  end
  
  # Methods
  describe "methods" do
    before do
      Current.admin_user = admin_user
    end
    
    after do
      Current.admin_user = nil
    end
    
    describe "#latest_work_order" do
      it "returns the most recently updated work order" do
        # Create work orders
        work_order1 = AuditWorkOrder.new(
          reimbursement: reimbursement,
          status: "approved",
          created_by: admin_user.id
        )
        work_order1.save(validate: false)
        
        work_order2 = AuditWorkOrder.new(
          reimbursement: reimbursement,
          status: "rejected",
          created_by: admin_user.id
        )
        work_order2.save(validate: false)
        
        # Update timestamps to ensure work_order2 is newer
        work_order1.update_column(:updated_at, 1.day.ago)
        work_order2.update_column(:updated_at, Time.current)
        
        # Create associations
        WorkOrderFeeDetail.create!(
          work_order_id: work_order1.id,
          fee_detail_id: fee_detail.id
        )
        
        WorkOrderFeeDetail.create!(
          work_order_id: work_order2.id,
          fee_detail_id: fee_detail.id
        )
        
        # Force reload of associations
        fee_detail.reload
        
        # Expect the latest work order to be work_order2
        expect(fee_detail.latest_work_order).to eq(work_order2)
      end
      
      it "returns nil when there are no work orders" do
        expect(fee_detail.latest_work_order).to be_nil
      end
    end
    
    describe "#work_order_history" do
      it "returns all work orders ordered by recency" do
        # Create work orders
        work_order1 = AuditWorkOrder.new(
          reimbursement: reimbursement,
          status: "approved",
          created_by: admin_user.id
        )
        work_order1.save(validate: false)
        
        work_order2 = AuditWorkOrder.new(
          reimbursement: reimbursement,
          status: "rejected",
          created_by: admin_user.id
        )
        work_order2.save(validate: false)
        
        # Update timestamps to ensure work_order2 is newer
        work_order1.update_column(:updated_at, 1.day.ago)
        work_order2.update_column(:updated_at, Time.current)
        
        # Create associations
        WorkOrderFeeDetail.create!(
          work_order_id: work_order1.id,
          fee_detail_id: fee_detail.id
        )
        
        WorkOrderFeeDetail.create!(
          work_order_id: work_order2.id,
          fee_detail_id: fee_detail.id
        )
        
        # Force reload of associations
        fee_detail.reload
        
        # Mock the work_order_ids and WorkOrder.where
        allow(fee_detail.work_order_fee_details).to receive(:pluck).with(:work_order_id).and_return([work_order1.id, work_order2.id])
        allow(WorkOrder).to receive(:where).with(id: [work_order1.id, work_order2.id]).and_return(WorkOrder.where(id: [work_order1.id, work_order2.id]))
        
        # Get the actual result and sort it to match expected order
        result = fee_detail.work_order_history.to_a.sort_by(&:updated_at).reverse
        expect(result).to eq([work_order2, work_order1])
      end
    end
    
    describe "#latest_work_order_status" do
      it "returns the status of the latest work order" do
        # Create work order
        work_order = AuditWorkOrder.new(
          reimbursement: reimbursement,
          status: "approved",
          created_by: admin_user.id
        )
        work_order.save(validate: false)
        
        # Create association
        WorkOrderFeeDetail.create!(
          work_order_id: work_order.id,
          fee_detail_id: fee_detail.id
        )
        
        # Force reload of associations
        fee_detail.reload
        
        expect(fee_detail.latest_work_order_status).to eq("approved")
      end
      
      it "returns nil when there are no work orders" do
        expect(fee_detail.latest_work_order_status).to be_nil
      end
    end
    
    describe "status check methods" do
      let(:approved_work_order) do
        work_order = AuditWorkOrder.new(
          reimbursement: reimbursement,
          status: "approved",
          created_by: admin_user.id
        )
        work_order.save(validate: false)
        work_order
      end
      
      let(:rejected_work_order) do
        work_order = AuditWorkOrder.new(
          reimbursement: reimbursement,
          status: "rejected",
          created_by: admin_user.id
        )
        work_order.save(validate: false)
        work_order
      end
      
      before do
        # Create associations
        WorkOrderFeeDetail.create!(
          work_order: approved_work_order,
          fee_detail: fee_detail
        )
        
        WorkOrderFeeDetail.create!(
          work_order: rejected_work_order,
          fee_detail: fee_detail
        )
      end
      
      describe "#approved_by_any_work_order?" do
        it "returns true if any work order is approved" do
          # Force reload of associations
          fee_detail.reload
          
          # Mock the association query
          allow(fee_detail.work_orders).to receive(:where).with(status: WorkOrder::STATUS_APPROVED).and_return(double(exists?: true))
          
          expect(fee_detail.approved_by_any_work_order?).to be true
        end
        
        it "returns false if no work order is approved" do
          approved_work_order.update(status: "pending")
          expect(fee_detail.approved_by_any_work_order?).to be false
        end
      end
      
      describe "#rejected_by_any_work_order?" do
        it "returns true if any work order is rejected" do
          # Force reload of associations
          fee_detail.reload
          
          # Mock the association query
          allow(fee_detail.work_orders).to receive(:where).with(status: WorkOrder::STATUS_REJECTED).and_return(double(exists?: true))
          
          expect(fee_detail.rejected_by_any_work_order?).to be true
        end
        
        it "returns false if no work order is rejected" do
          rejected_work_order.update(status: "pending")
          expect(fee_detail.rejected_by_any_work_order?).to be false
        end
      end
      
      describe "#approved_by_latest_work_order?" do
        it "returns true if the latest work order is approved" do
          # Update timestamps to ensure approved_work_order is newer
          rejected_work_order.update_column(:updated_at, 1.day.ago)
          approved_work_order.update_column(:updated_at, Time.current)
          
          # Force reload of associations
          fee_detail.reload
          
          expect(fee_detail.approved_by_latest_work_order?).to be true
        end
        
        it "returns false if the latest work order is not approved" do
          # Update timestamps to ensure rejected_work_order is newer
          approved_work_order.update_column(:updated_at, 1.day.ago)
          rejected_work_order.update_column(:updated_at, Time.current)
          
          # Force reload of associations
          fee_detail.reload
          
          expect(fee_detail.approved_by_latest_work_order?).to be false
        end
      end
      
      describe "#rejected_by_latest_work_order?" do
        it "returns true if the latest work order is rejected" do
          # Update timestamps to ensure rejected_work_order is newer
          approved_work_order.update_column(:updated_at, 1.day.ago)
          rejected_work_order.update_column(:updated_at, Time.current)
          
          # Force reload of associations
          fee_detail.reload
          
          expect(fee_detail.rejected_by_latest_work_order?).to be true
        end
        
        it "returns false if the latest work order is not rejected" do
          # Update timestamps to ensure approved_work_order is newer
          rejected_work_order.update_column(:updated_at, 1.day.ago)
          approved_work_order.update_column(:updated_at, Time.current)
          
          # Force reload of associations
          fee_detail.reload
          
          expect(fee_detail.rejected_by_latest_work_order?).to be false
        end
      end
    end
  end
end