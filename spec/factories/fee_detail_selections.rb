# spec/factories/fee_detail_selections.rb
FactoryBot.define do
  factory :fee_detail_selection do
    fee_detail
    association :work_order, factory: :audit_work_order
    verification_comment { "测试验证备注" }
    # verification_status has been removed from the model
    # verified_at and verifier_id are still in the model but optional
    
    # 自动设置work_order_type为关联工单的类名
    work_order_type { work_order.class.name }
  end
end