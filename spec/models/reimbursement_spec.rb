# spec/models/reimbursement_spec.rb
require 'rails_helper'

RSpec.describe Reimbursement, type: :model do
  let(:admin_user) { create(:admin_user) }

  # 验证测试
  describe "validations" do
    it { should validate_presence_of(:invoice_number) }
    
    # Use a subject with all required attributes for uniqueness validation
    subject { create(:reimbursement) }
    it { should validate_uniqueness_of(:invoice_number) }
    # Rewrite presence and numericality validations using manual checks
    it "validates presence of required fields" do
      reimbursement = build(:reimbursement, document_name: nil, applicant: nil, applicant_id: nil, company: nil, department: nil, amount: nil)
      expect(reimbursement).not_to be_valid
      expect(reimbursement.errors[:document_name]).to include("不能为空")
      expect(reimbursement.errors[:applicant]).to include("不能为空")
      expect(reimbursement.errors[:applicant_id]).to include("不能为空")
      expect(reimbursement.errors[:company]).to include("不能为空")
      expect(reimbursement.errors[:department]).to include("不能为空")
      expect(reimbursement.errors[:amount]).to include("不能为空")
    end

    it "validates numericality of amount" do
      reimbursement = build(:reimbursement, amount: 0)
      expect(reimbursement).not_to be_valid
      expect(reimbursement.errors[:amount]).to include("必须大于0") # Updated error message

      reimbursement.amount = -100
      expect(reimbursement).not_to be_valid
      expect(reimbursement.errors[:amount]).to include("必须大于0") # Updated error message

      reimbursement.amount = "abc"
      expect(reimbursement).not_to be_valid
      expect(reimbursement.errors[:amount]).to include("不是数字") # Updated error message
    end

    it { should validate_inclusion_of(:status).in_array(%w[pending processing close]) }
    it { should validate_inclusion_of(:is_electronic).in_array([true, false]) }

    # Rewrite inclusion validation for receipt_status using manual checks
    it "validates inclusion of receipt_status" do
      reimbursement = build(:reimbursement, receipt_status: "invalid_status")
      expect(reimbursement).not_to be_valid
      expect(reimbursement.errors[:receipt_status]).to include("不包含于列表中") # Updated error message
    end

    # Rewrite validation for external_status using manual checks
    it "allows external_status to be nil" do
      reimbursement = build(:reimbursement, external_status: nil)
      expect(reimbursement).to be_valid
    end

    it "allows valid values for external_status" do
       reimbursement = build(:reimbursement, external_status: "Some External Status")
       expect(reimbursement).to be_valid
    end
    # Assuming 'approved?' method exists on Reimbursement for these validations
    # it { should validate_presence_of(:approval_date).if(:approved?) }
    # it { should validate_presence_of(:approver_name).if(:approved?) }
  end

  # 关联测试
  describe "associations" do
    it { should have_many(:work_orders).dependent(:destroy) }
    it { should have_many(:audit_work_orders).class_name('AuditWorkOrder') }
    it { should have_many(:communication_work_orders).class_name('CommunicationWorkOrder') }
    it { should have_many(:express_receipt_work_orders).class_name('ExpressReceiptWorkOrder') }
    it { should have_many(:fee_details).with_foreign_key('document_number').with_primary_key('invoice_number').dependent(:destroy) }
    it { should have_many(:operation_histories).with_foreign_key('document_number').with_primary_key('invoice_number').dependent(:destroy) }
  end

  # 测试 reimbursement 的状态变化基于费用明细
  describe "reimbursement status changes based on fee details" do
    let(:reimbursement) { create(:reimbursement) }
    let!(:fee_detail1) { create(:fee_detail, reimbursement: reimbursement, verification_status: 'pending') }
    let!(:fee_detail2) { create(:fee_detail, reimbursement: reimbursement, verification_status: 'pending') }

    context "when all fee details are verified" do
      it "allows reimbursement to be marked as close" do
        # 确保报销单处于processing状态
        reimbursement.update(status: 'processing')
        fee_detail1.update(verification_status: 'verified')
        expect(reimbursement.reload.status).to eq('processing') # Still processing as not all are verified

        fee_detail2.update(verification_status: 'verified')
        
        # 验证所有费用明细已验证
        expect(reimbursement.all_fee_details_verified?).to be true
        
        # 验证可以将报销单标记为close
        expect(reimbursement.can_mark_as_close?).to be true
        expect { reimbursement.mark_as_close! }.not_to raise_error
        expect(reimbursement.reload.status).to eq('close')
      end
    end

    context "when a fee detail is marked as problematic" do
      it "prevents reimbursement from being marked as close" do
        # 设置报销单在processing状态
        reimbursement.update(status: 'processing')
        fee_detail1.update(verification_status: 'verified')
        fee_detail2.update(verification_status: 'verified')
        
        # 将一个费用明细标记为problematic
        fee_detail1.update(verification_status: 'problematic')
        
        # 验证不是所有费用明细都已验证
        expect(reimbursement.all_fee_details_verified?).to be false
        
        # 验证不能将报销单标记为close
        expect(reimbursement.can_mark_as_close?).to be false
        expect { reimbursement.mark_as_close! }.to raise_error(ActiveRecord::RecordInvalid, /存在未验证的费用明细/)
      end
    end

    context "when a fee detail is marked as pending" do
      it "prevents reimbursement from being marked as close" do
        # 设置报销单在processing状态
        reimbursement.update(status: 'processing')
        fee_detail1.update(verification_status: 'verified')
        fee_detail2.update(verification_status: 'verified')
        
        # 将一个费用明细标记为pending
        fee_detail1.update(verification_status: 'pending')
        
        # 验证不是所有费用明细都已验证
        expect(reimbursement.all_fee_details_verified?).to be false
        
        # 验证不能将报销单标记为close
        expect(reimbursement.can_mark_as_close?).to be false
        expect { reimbursement.mark_as_close! }.to raise_error(ActiveRecord::RecordInvalid, /存在未验证的费用明细/)
      end
    end
  end
end