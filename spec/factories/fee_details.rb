# spec/factories/fee_details.rb
FactoryBot.define do
  factory :fee_detail do
    sequence(:document_number) { |n| "R#{100000 + n}" }
    fee_type { ["交通费", "餐费", "住宿费", "办公用品"].sample }
    amount { rand(10.0..1000.0).round(2) }
    currency { "CNY" }
    fee_date { Date.current - rand(1..30).days }
    payment_method { ["现金", "信用卡", "公司账户"].sample }
    verification_status { "pending" }
    month_belonging { Date.current.strftime("%Y%m") }
    first_submission_date { Time.current - rand(1..10).days }
    
    trait :verified do
      verification_status { "verified" }
    end
    
    trait :problematic do
      verification_status { "problematic" }
    end
    
    # 关联到报销单的特性
    trait :with_reimbursement do
      association :reimbursement, strategy: :build
      document_number { reimbursement.invoice_number }
    end
  end

  # Add a simple validation test for the factory
  RSpec.describe "FeeDetail factory" do
    # The default factory does not associate with a reimbursement,
    # but document_number is required. This test will fail if document_number
    # is not set by default or if the model requires a valid reimbursement association.
    # Based on the model, document_number is required, but reimbursement association is optional.
    # The factory sets document_number with a sequence, so it should be valid.
    it "is valid" do
      expect(build(:fee_detail)).to be_valid
    end

    # Test the trait with reimbursement
    it "is valid with reimbursement trait" do
      expect(build(:fee_detail, :with_reimbursement)).to be_valid
    end
  end
end