# spec/factories/fee_detail_selections.rb
FactoryBot.define do
  factory :fee_detail_selection do
    fee_detail
    association :work_order, factory: :audit_work_order
    verification_status { "pending" }
    verification_comment { "测试验证备注" }
    # Remove verified_at and verified_by fields as they seem to be undefined
  end
end