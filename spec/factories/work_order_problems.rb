FactoryBot.define do
  factory :work_order_problem do
    association :work_order, factory: :audit_work_order
    association :problem_type
  end
end