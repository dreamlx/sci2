# spec/factories/work_order_status_changes.rb
FactoryBot.define do
  factory :work_order_status_change do
    association :work_order, factory: :audit_work_order
    from_status { nil }
    to_status { 'pending' }
    changed_at { Time.current }
    # Remove changed_by field as it seems to be undefined
  end
end
