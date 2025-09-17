# spec/factories/work_orders.rb
FactoryBot.define do
  factory :work_order do
    association :reimbursement
    association :creator, factory: :admin_user
    status { "pending" } # 默认状态
    
    # 共享字段
    processing_opinion { nil }
    audit_comment { "测试审核意见" }
    
    # 不能直接创建基类实例，必须使用子类工厂
    initialize_with { raise "Cannot create WorkOrder directly, use a subclass factory" }
    
    # 子类工厂
    factory :express_receipt_work_order, class: 'ExpressReceiptWorkOrder' do
      type { "ExpressReceiptWorkOrder" }
      status { "completed" }
      sequence(:tracking_number) { |n| "SF#{1000 + n}" }
      received_at { Time.current - 1.day }
      courier_name { "顺丰" }
      
      # 明确设置共享字段为nil或合适的值
      processing_opinion { nil }
      problem_type { nil }
      
      # 覆盖基类的 initialize_with
      initialize_with { ExpressReceiptWorkOrder.new }
    end
    
    factory :audit_work_order, class: 'AuditWorkOrder' do
      type { "AuditWorkOrder" }
      status { "pending" }
      
      # 覆盖基类的 initialize_with
      initialize_with { AuditWorkOrder.new }
      
      # 添加回调以设置fee_detail_ids_to_select
      after(:build) do |audit_work_order, evaluator|
        # 如果没有设置fee_detail_ids_to_select，则设置一个空数组
        audit_work_order.instance_variable_set('@fee_detail_ids_to_select', []) unless audit_work_order.instance_variable_get('@fee_detail_ids_to_select')
      end
      
      trait :processing do
        status { "processing" }
      end
      
      trait :approved do
        status { "approved" }
        audit_result { "approved" }
        audit_date { Time.current }
      end
      
      trait :rejected do
        status { "rejected" }
        audit_result { "rejected" }
        audit_date { Time.current }
        audit_comment { "测试拒绝原因" }
        association :problem_type, factory: :problem_type
      end
    end
    
    factory :communication_work_order, class: 'CommunicationWorkOrder' do
      type { "CommunicationWorkOrder" }
      status { "pending" }
      communication_method { "电话" }
      audit_comment { "这是一个详细的沟通记录，包含了所有必要的信息用于测试" }
      
      # 覆盖基类的 initialize_with
      initialize_with { CommunicationWorkOrder.new }
      
      # 重构后的沟通工单会自动完成，但在测试中我们可能需要控制状态
      trait :completed do
        status { "completed" }
      end
      
      # 不同沟通方式的变体
      trait :phone do
        communication_method { "电话" }
      end
      
      trait :wechat do
        communication_method { "微信" }
      end
      
      trait :email do
        communication_method { "邮件" }
      end
      
      trait :in_person do
        communication_method { "现场沟通" }
      end
    end
  end
end