# spec/factories/operation_histories.rb
FactoryBot.define do
  factory :operation_history do
    sequence(:document_number) { |n| "R#{Time.now.year}#{sprintf('%06d', n)}" }
    operation_type { ["提交", "审核", "审批", "退回", "撤回"].sample }
    operation_time { Time.current - rand(1..30).days }
    operator { "测试用户#{rand(1..10)}" }
    notes { ["正常处理", "审核通过", "审批通过", "有问题退回", "申请人撤回"].sample }
    form_type { "报销单" }
    operation_node { ["提交", "部门审核", "财务审核", "财务经理审批"].sample }
    
    trait :with_reimbursement do
      transient do
        reimbursement { create(:reimbursement) }
      end
      
      document_number { reimbursement.invoice_number }
    end
    
    trait :approval do
      operation_type { "审批" }
      notes { "审批通过" }
      operation_node { "财务经理审批" }
    end
    
    trait :rejection do
      operation_type { "退回" }
      notes { "有问题退回" }
      operation_node { "财务审核" }
    end
  end

  # Add simple validation tests for the factory
  RSpec.describe "OperationHistory factory" do
    # The default factory sets document_number with a sequence, so it should be valid
    it "is valid" do
      expect(build(:operation_history)).to be_valid
    end

    # Test the trait with reimbursement
    it "is valid with reimbursement trait" do
      expect(build(:operation_history, :with_reimbursement)).to be_valid
    end
  end
end