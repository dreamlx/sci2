require 'rails_helper'

RSpec.describe Reimbursement, type: :model do
  let(:reimbursement) do
    Reimbursement.create!(
      invoice_number: "INV-001",
      document_name: "个人报销单",
      status: "processing",
      is_electronic: true
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
    it { should have_many(:fee_details).with_foreign_key('document_number').with_primary_key('invoice_number').dependent(:destroy) }
    it { should have_many(:work_orders).dependent(:destroy) }
    it { should have_many(:audit_work_orders) }
    it { should have_many(:communication_work_orders) }
    it { should have_many(:express_receipt_work_orders) }
    it { should have_many(:operation_histories).with_foreign_key('document_number').with_primary_key('invoice_number').dependent(:destroy) }
  end
  
  # Validations
  describe "validations" do
    it { should validate_presence_of(:invoice_number) }
    
    describe "uniqueness validation" do
      subject { Reimbursement.new(invoice_number: "INV-TEST", document_name: "Test", status: "pending", is_electronic: true) }
      it { should validate_uniqueness_of(:invoice_number) }
    end
    
    it { should validate_inclusion_of(:status).in_array(Reimbursement::STATUSES) }
    it { should validate_inclusion_of(:is_electronic).in_array([true, false]) }
  end
  
  # Scopes
  describe "scopes" do
    it "has a scope for pending reimbursements" do
      expect(Reimbursement).to respond_to(:pending)
    end
    
    it "has a scope for processing reimbursements" do
      expect(Reimbursement).to respond_to(:processing)
    end
    
    it "has a scope for closed reimbursements" do
      expect(Reimbursement).to respond_to(:closed)
    end
    
    it "has a scope for electronic reimbursements" do
      expect(Reimbursement).to respond_to(:electronic)
    end
    
    it "has a scope for non-electronic reimbursements" do
      expect(Reimbursement).to respond_to(:non_electronic)
    end
  end
  
  # State Machine
  describe "state machine" do
    it "has a state machine for status" do
      expect(Reimbursement.state_machines[:status]).to be_present
    end
    
    it "starts with pending status" do
      new_reimbursement = Reimbursement.new
      expect(new_reimbursement.status).to eq("pending")
    end
    
    it "can transition from pending to processing" do
      reimbursement = Reimbursement.create!(
        invoice_number: "INV-002",
        document_name: "测试报销单",
        is_electronic: true
      )
      
      expect(reimbursement.status).to eq("pending")
      expect(reimbursement.start_processing).to be true
      expect(reimbursement.status).to eq("processing")
    end
    
    it "can transition from processing to closed" do
      reimbursement.update(status: "processing")
      
      expect(reimbursement.status).to eq("processing")
      expect(reimbursement.close_processing).to be true
      expect(reimbursement.status).to eq("closed")
    end
    
    it "can transition from closed to processing" do
      reimbursement.update(status: "closed")
      
      expect(reimbursement.status).to eq("closed")
      expect(reimbursement.reopen_to_processing).to be true
      expect(reimbursement.status).to eq("processing")
    end
  end
  
  # Methods
  describe "methods" do
    describe "status helper methods" do
      it "returns true for pending? when status is pending" do
        reimbursement.update(status: "pending")
        expect(reimbursement.pending?).to be true
      end
      
      it "returns true for processing? when status is processing" do
        reimbursement.update(status: "processing")
        expect(reimbursement.processing?).to be true
      end
      
      it "returns true for closed? when status is closed" do
        reimbursement.update(status: "closed")
        expect(reimbursement.closed?).to be true
      end
      
      it "returns true for electronic? when is_electronic is true" do
        reimbursement.update(is_electronic: true)
        expect(reimbursement.electronic?).to be true
      end
    end
    
    describe "#all_fee_details_verified?" do
      it "returns true when all fee details are verified" do
        # Create fee details
        fee_detail1 = FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: "交通费",
          amount: 100.0,
          verification_status: "verified"
        )
        
        fee_detail2 = FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: "住宿费",
          amount: 200.0,
          verification_status: "verified"
        )
        
        expect(reimbursement.all_fee_details_verified?).to be true
      end
      
      it "returns false when any fee detail is not verified" do
        # Create fee details
        fee_detail1 = FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: "交通费",
          amount: 100.0,
          verification_status: "verified"
        )
        
        fee_detail2 = FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: "住宿费",
          amount: 200.0,
          verification_status: "problematic"
        )
        
        expect(reimbursement.all_fee_details_verified?).to be false
      end
      
      it "returns false when there are no fee details" do
        expect(reimbursement.all_fee_details_verified?).to be false
      end
    end
    
    describe "#any_fee_details_problematic?" do
      it "returns true when any fee detail is problematic" do
        # Create fee details
        fee_detail1 = FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: "交通费",
          amount: 100.0,
          verification_status: "verified"
        )
        
        fee_detail2 = FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: "住宿费",
          amount: 200.0,
          verification_status: "problematic"
        )
        
        expect(reimbursement.any_fee_details_problematic?).to be true
      end
      
      it "returns false when no fee detail is problematic" do
        # Create fee details
        fee_detail1 = FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: "交通费",
          amount: 100.0,
          verification_status: "verified"
        )
        
        fee_detail2 = FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: "住宿费",
          amount: 200.0,
          verification_status: "pending"
        )
        
        expect(reimbursement.any_fee_details_problematic?).to be false
      end
    end
    
    describe "#can_be_closed?" do
      it "returns true when processing and all fee details are verified" do
        reimbursement.update(status: "processing")
        
        # Create verified fee details
        fee_detail = FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: "交通费",
          amount: 100.0,
          verification_status: "verified"
        )
        
        expect(reimbursement.can_be_closed?).to be true
      end
      
      it "returns false when not processing" do
        reimbursement.update(status: "pending")
        
        # Create verified fee details
        fee_detail = FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: "交通费",
          amount: 100.0,
          verification_status: "verified"
        )
        
        expect(reimbursement.can_be_closed?).to be false
      end
      
      it "returns false when not all fee details are verified" do
        reimbursement.update(status: "processing")
        
        # Create problematic fee detail
        fee_detail = FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: "交通费",
          amount: 100.0,
          verification_status: "problematic"
        )
        
        expect(reimbursement.can_be_closed?).to be false
      end
    end
    
    describe "#close!" do
      it "closes the reimbursement when it can be closed" do
        reimbursement.update(status: "processing")
        
        # Create verified fee details
        fee_detail = FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: "交通费",
          amount: 100.0,
          verification_status: "verified"
        )
        
        expect(reimbursement.close!).to be true
        expect(reimbursement.status).to eq("closed")
      end
      
      it "returns false when it cannot be closed" do
        reimbursement.update(status: "processing")
        
        # Create problematic fee detail
        fee_detail = FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: "交通费",
          amount: 100.0,
          verification_status: "problematic"
        )
        
        expect(reimbursement.close!).to be false
        expect(reimbursement.status).to eq("processing")
      end
    end
    
    describe "#update_status_based_on_fee_details!" do
      context "when processing" do
        before do
          reimbursement.update(status: "processing")
        end
        
        it "closes the reimbursement when all fee details are verified" do
          # Create verified fee details
          fee_detail = FeeDetail.create!(
            document_number: reimbursement.invoice_number,
            fee_type: "交通费",
            amount: 100.0,
            verification_status: "verified"
          )
          
          reimbursement.update_status_based_on_fee_details!
          expect(reimbursement.status).to eq("closed")
        end
        
        it "keeps the reimbursement processing when not all fee details are verified" do
          # Create problematic fee detail
          fee_detail = FeeDetail.create!(
            document_number: reimbursement.invoice_number,
            fee_type: "交通费",
            amount: 100.0,
            verification_status: "problematic"
          )
          
          reimbursement.update_status_based_on_fee_details!
          expect(reimbursement.status).to eq("processing")
        end
      end
      
      context "when closed" do
        before do
          reimbursement.update(status: "closed")
        end
        
        it "reopens the reimbursement when any fee detail is problematic" do
          # Create problematic fee detail
          fee_detail = FeeDetail.create!(
            document_number: reimbursement.invoice_number,
            fee_type: "交通费",
            amount: 100.0,
            verification_status: "problematic"
          )
          
          reimbursement.update_status_based_on_fee_details!
          expect(reimbursement.status).to eq("processing")
        end
        
        it "keeps the reimbursement closed when no fee detail is problematic" do
          # Create verified fee detail
          fee_detail = FeeDetail.create!(
            document_number: reimbursement.invoice_number,
            fee_type: "交通费",
            amount: 100.0,
            verification_status: "verified"
          )
          
          reimbursement.update_status_based_on_fee_details!
          expect(reimbursement.status).to eq("closed")
        end
      end
    end
    
    describe "#reopen_to_processing!" do
      it "reopens a closed reimbursement to processing" do
        reimbursement.update(status: "closed")
        
        expect(reimbursement.reopen_to_processing!).to be true
        expect(reimbursement.status).to eq("processing")
      end
      
      it "returns false when the reimbursement is not closed" do
        reimbursement.update(status: "processing")
        
        expect(reimbursement.reopen_to_processing!).to be false
        expect(reimbursement.status).to eq("processing")
      end
    end
    
    describe "#can_create_work_orders?" do
      it "returns true when not closed" do
        reimbursement.update(status: "processing")
        expect(reimbursement.can_create_work_orders?).to be true
        
        reimbursement.update(status: "pending")
        expect(reimbursement.can_create_work_orders?).to be true
      end
      
      it "returns false when closed" do
        reimbursement.update(status: "closed")
        expect(reimbursement.can_create_work_orders?).to be false
      end
    end
    
    describe "#meeting_type_context" do
      it "returns '个人' for personal expense documents" do
        reimbursement.update(document_name: "个人交通费报销单")
        expect(reimbursement.meeting_type_context).to eq("个人")
      end
      
      it "returns '学术论坛' for academic expense documents" do
        reimbursement.update(document_name: "学术会议报销单")
        expect(reimbursement.meeting_type_context).to eq("学术论坛")
      end
      
      it "returns '个人' as default" do
        reimbursement.update(document_name: "其他报销单")
        expect(reimbursement.meeting_type_context).to eq("个人")
      end
    end
  end
end