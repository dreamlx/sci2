# spec/factories/fee_detail_selections.rb
FactoryBot.define do
  factory :fee_detail_selection do
    association :fee_detail
    association :work_order, factory: :audit_work_order
    work_order_type { "AuditWorkOrder" }
    verification_status { "pending" }
    
    trait :verified do
      verification_status { "verified" }
    end
    
    trait :problematic do
      verification_status { "problematic" }
    end
  end
end