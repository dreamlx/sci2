# spec/factories/work_order_operations.rb
FactoryBot.define do
  factory :work_order_operation do
    association :work_order, factory: :audit_work_order
    association :admin_user
    operation_type { WorkOrderOperation.operation_types.sample }
    details { { message: "Test operation details" }.to_json }
    previous_state { { status: "pending" }.to_json }
    current_state { { status: "approved" }.to_json }
    created_at { Time.current }
  end
end