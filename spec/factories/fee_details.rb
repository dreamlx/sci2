FactoryBot.define do
  factory :fee_detail do
    sequence(:document_number) { |n| "R#{Time.current.strftime('%Y%m%d')}#{n.to_s.rjust(3, '0')}" }
    fee_type { ["交通费", "餐饮费", "住宿费", "办公用品", "其他"].sample }
    amount { rand(10.0..1000.0).round(2) }
    currency { "CNY" }
    fee_date { Time.current - rand(1..30).days }
    payment_method { ["现金", "信用卡", "公司转账", "其他"].sample }
    verification_status { "pending" }

    trait :verified do
      verification_status { "verified" }
    end

    trait :rejected do
      verification_status { "rejected" }
    end

    trait :problematic do
      verification_status { "problematic" }
    end

    trait :with_reimbursement do
      association :reimbursement, strategy: :build
      document_number { reimbursement.invoice_number }
    end
  end
end