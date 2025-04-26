require 'rails_helper'

RSpec.describe Reimbursement, type: :model do
  describe "validations" do
    it { should validate_presence_of(:invoice_number) }
    it { should validate_uniqueness_of(:invoice_number) }
    it { should validate_presence_of(:document_name) }
    it { should validate_presence_of(:applicant) }
    it { should validate_presence_of(:applicant_id) }
  end
  
  describe "associations" do
    it { should have_many(:express_receipt_work_orders).dependent(:destroy) }
    it { should have_many(:audit_work_orders).dependent(:destroy) }
    it { should have_many(:communication_work_orders).dependent(:destroy) }
    it { should have_many(:fee_details) }
    it { should have_many(:operation_histories) }
  end
  
  describe "callbacks" do
    context "when creating a non-electronic reimbursement" do
      it "creates an audit work order" do
        reimbursement = build(:reimbursement, is_electronic: false)
        expect { reimbursement.save }.to change(AuditWorkOrder, :count).by(1)
        
        audit_work_order = reimbursement.audit_work_orders.first
        expect(audit_work_order.status).to eq('pending')
      end
    end
    
    context "when creating an electronic reimbursement" do
      it "does not create an audit work order" do
        reimbursement = build(:reimbursement, is_electronic: true)
        expect { reimbursement.save }.not_to change(AuditWorkOrder, :count)
      end
    end
  end
  
  describe "scopes" do
    before do
      create(:reimbursement, is_electronic: true)
      create(:reimbursement, is_electronic: false)
      create(:reimbursement, is_complete: true)
      create(:reimbursement, receipt_status: 'received')
    end
    
    it "returns electronic reimbursements" do
      expect(Reimbursement.electronic.count).to eq(1)
    end
    
    it "returns non-electronic reimbursements" do
      expect(Reimbursement.non_electronic.count).to eq(3)
    end
    
    it "returns completed reimbursements" do
      expect(Reimbursement.completed.count).to eq(1)
    end
    
    it "returns pending reimbursements" do
      expect(Reimbursement.pending.count).to eq(3)
    end
    
    it "returns received reimbursements" do
      expect(Reimbursement.received.count).to eq(1)
    end
    
    it "returns not received reimbursements" do
      expect(Reimbursement.not_received.count).to eq(3)
    end
  end
  
  describe "#mark_as_received" do
    let(:reimbursement) { create(:reimbursement) }
    
    it "updates receipt status and date" do
      receipt_date = Time.current
      reimbursement.mark_as_received(receipt_date)
      
      expect(reimbursement.receipt_status).to eq('received')
      expect(reimbursement.receipt_date).to be_within(1.second).of(receipt_date)
    end
  end
  
  describe "#mark_as_complete" do
    let(:reimbursement) { create(:reimbursement) }
    
    it "updates complete flag and reimbursement status" do
      reimbursement.mark_as_complete
      
      expect(reimbursement.is_complete).to be_truthy
      expect(reimbursement.reimbursement_status).to eq('closed')
    end
  end
  
  describe "#create_audit_work_order" do
    let(:reimbursement) { create(:reimbursement, is_electronic: true) }
    let(:created_by) { 1 }
    
    it "creates an audit work order" do
      expect { reimbursement.create_audit_work_order(created_by) }.to change(AuditWorkOrder, :count).by(1)
      
      audit_work_order = reimbursement.audit_work_orders.first
      expect(audit_work_order.status).to eq('pending')
      expect(audit_work_order.created_by).to eq(created_by)
    end
  end
end