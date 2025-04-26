FactoryBot.define do
  factory :express_receipt_work_order do
    association :reimbursement
    status { "received" }
    tracking_number { "SF#{rand(10**10)}" }
    received_at { Time.current }
    courier_name { ["顺丰", "圆通", "中通", "申通", "韵达"].sample }
    created_by { 1 }
    
    trait :processed do
      status { "processed" }
    end
    
    trait :completed do
      status { "completed" }
    end
  end
end