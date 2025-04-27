FactoryBot.define do
  factory :work_order_status_change do
    work_order_type { ["express_receipt", "audit", "communication"].sample }
    sequence(:work_order_id) { |n| n }
    from_status { nil }
    to_status { "pending" }
    changed_at { Time.current }
    changed_by { 1 }

    trait :for_express_receipt do
      work_order_type { "express_receipt" }
      association :work_order, factory: :express_receipt_work_order
    end

    trait :for_audit do
      work_order_type { "audit" }
      association :work_order, factory: :audit_work_order
    end

    trait :for_communication do
      work_order_type { "communication" }
      association :work_order, factory: :communication_work_order
    end

    trait :with_reason do
      reason { "状态变更原因" }
    end
  end
end