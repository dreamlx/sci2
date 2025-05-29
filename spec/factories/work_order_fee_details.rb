# spec/factories/work_order_fee_details.rb
FactoryBot.define do
  factory :work_order_fee_detail do
    fee_detail
    association :work_order, factory: :audit_work_order
    
    # Automatically set work_order_type to the class name of the associated work order
    work_order_type { work_order.class.name }
  end
end