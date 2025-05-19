# spec/factories/fee_details.rb
FactoryBot.define do
  factory :fee_detail do
    sequence(:document_number) { |n| "R#{100000 + n}" }
    fee_type { ["交通费", "餐费", "住宿费", "办公用品"].sample }
    amount { rand(10.0..1000.0).round(2) }
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
end