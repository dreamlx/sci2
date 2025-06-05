# spec/factories/work_order_fee_details.rb
FactoryBot.define do
  factory :work_order_fee_detail do
    fee_detail
    association :work_order, factory: :audit_work_order
  end
end