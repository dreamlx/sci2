require 'rails_helper'

RSpec.describe ExpressReceiptWorkOrder, type: :model do
  describe "validations" do
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[received processed completed]) }
    it { should validate_presence_of(:tracking_number) }
  end
  
  describe "associations" do
    it { should belong_to(:reimbursement) }
    it { should have_one(:audit_work_order) }
    it { should have_many(:work_order_status_changes).dependent(:destroy) }
  end
  
  describe "state machine" do
    let(:work_order) { create(:express_receipt_work_order) }
    
    context "when in received state" do
      it "can transition to processed" do
        expect(work_order.status).to eq("received")
        expect(work_order).to allow_event(:process)
        expect(work_order).not_to allow_event(:complete)
      end
      
      it "changes status to processed after process event" do
        work_order.process!
        expect(work_order.status).to eq("processed")
      end
    end
    
    context "when in processed state" do
      let(:work_order) { create(:express_receipt_work_order, :processed) }
      
      it "can transition to completed" do
        expect(work_order.status).to eq("processed")
        expect(work_order).to allow_event(:complete)
        expect(work_order).not_to allow_event(:process)
      end
      
      it "changes status to completed after complete event" do
        work_order.complete!
        expect(work_order.status).to eq("completed")
      end
      
      it "creates an audit work order after complete event" do
        expect { work_order.complete! }.to change(AuditWorkOrder, :count).by(1)
        
        audit_work_order = work_order.audit_work_order
        expect(audit_work_order.status).to eq("pending")
        expect(audit_work_order.reimbursement).to eq(work_order.reimbursement)
        expect(audit_work_order.express_receipt_work_order).to eq(work_order)
      end
    end
  end
  
  describe "callbacks" do
    let(:work_order) { create(:express_receipt_work_order) }
    
    context "when status changes" do
      before do
        allow(Current).to receive(:admin_user).and_return(double(id: 1))
      end
      
      it "records status change" do
        expect { work_order.process! }.to change(WorkOrderStatusChange, :count).by(1)
        
        status_change = work_order.work_order_status_changes.last
        expect(status_change.work_order_type).to eq("express_receipt")
        expect(status_change.from_status).to eq("received")
        expect(status_change.to_status).to eq("processed")
        expect(status_change.changed_by).to eq(1)
      end
    end
  end
  
  describe "#create_audit_work_order" do
    let(:work_order) { create(:express_receipt_work_order, :processed, created_by: 1) }
    
    it "creates an audit work order" do
      expect { work_order.create_audit_work_order }.to change(AuditWorkOrder, :count).by(1)
      
      audit_work_order = work_order.audit_work_order
      expect(audit_work_order.status).to eq("pending")
      expect(audit_work_order.reimbursement).to eq(work_order.reimbursement)
      expect(audit_work_order.express_receipt_work_order).to eq(work_order)
      expect(audit_work_order.created_by).to eq(1)
    end
  end
end