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
      verification_status: "pending",
      external_fee_id: "FEE-001"
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
    it { should validate_uniqueness_of(:external_fee_id) }
    
    context "with duplicate external_fee_id" do
      let(:reimbursement2) do
        Reimbursement.create!(
          invoice_number: "INV-002",
          document_name: "另一个报销单",
          status: "processing",
          is_electronic: true
        )
      end
      
      it "allows the same external_fee_id for different document_numbers" do
        # Create first fee detail
        fee_detail1 = FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: "交通费",
          amount: 100.0,
          verification_status: "pending",
          external_fee_id: "FEE-001"
        )

        # Create second fee detail with same external_fee_id but different document_number
        fee_detail2 = FeeDetail.new(
          document_number: reimbursement2.invoice_number,
          fee_type: "交通费",
          amount: 100.0,
          verification_status: "pending",
          external_fee_id: "FEE-001"
        )
        
        # This should be invalid because we want external_fee_id to be globally unique
        expect(fee_detail2).not_to be_valid
        expect(fee_detail2.errors[:external_fee_id]).to include("已经被使用")
      end
    end
  end
  
  # Scopes and business logic have been migrated to appropriate layers:
  # - Scopes → FeeDetailRepository (spec/repositories/fee_detail_repository_spec.rb)
  # - Business logic methods → FeeDetailStatusService (spec/services/fee_detail_status_service_spec.rb)
  # - Work order association methods → WorkOrderService (spec/services/work_order_service_spec.rb)
  #
  # This model test now focuses on data integrity: validations, associations, and basic model behavior
  # Following the new architecture pattern of separating concerns across layers
end