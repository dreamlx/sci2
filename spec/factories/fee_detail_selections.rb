FactoryBot.define do
  factory :fee_detail_selection do
    association :fee_detail
    verification_status { "pending" }

    trait :for_audit_work_order do
      association :audit_work_order
      communication_work_order_id { nil }
    end

    trait :for_communication_work_order do
      association :communication_work_order
      audit_work_order_id { nil }
    end

    trait :verified do
      verification_status { "verified" }
      verified_at { Time.current }
      verified_by { 1 }
    end

    trait :rejected do
      verification_status { "rejected" }
      verified_at { Time.current }
      verified_by { 1 }
    end

    trait :problematic do
      verification_status { "problematic" }
      verified_at { Time.current }
      verified_by { 1 }
    end

    trait :with_comment do
      verification_comment { "验证备注" }
    end
  end
end