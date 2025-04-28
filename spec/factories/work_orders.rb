# spec/factories/work_orders.rb
FactoryBot.define do
  factory :work_order do
    association :reimbursement
    association :creator, factory: :admin_user
    status { "pending" } # 默认状态
    
    # 共享字段
    problem_type { nil }
    problem_description { nil }
    remark { nil }
    processing_opinion { nil }
    
    # 不能直接创建基类实例，必须使用子类工厂
    initialize_with { raise "Cannot create WorkOrder directly, use a subclass factory" }
    
    # 子类工厂
    factory :express_receipt_work_order, class: 'ExpressReceiptWorkOrder' do
      type { "ExpressReceiptWorkOrder" }
      status { "completed" }
      sequence(:tracking_number) { |n| "SF#{1000 + n}" }
      received_at { Time.current - 1.day }
      courier_name { "顺丰" }
      
      # 覆盖基类的 initialize_with
      initialize_with { ExpressReceiptWorkOrder.new }
    end
    
    factory :audit_work_order, class: 'AuditWorkOrder' do
      type { "AuditWorkOrder" }
      status { "pending" }
      
      # 覆盖基类的 initialize_with
      initialize_with { AuditWorkOrder.new }
      
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
        problem_type { "documentation_issue" }
      end
    end
    
    factory :communication_work_order, class: 'CommunicationWorkOrder' do
      type { "CommunicationWorkOrder" }
      status { "pending" }
      association :audit_work_order
      
      # 覆盖基类的 initialize_with
      initialize_with { CommunicationWorkOrder.new }
      
      trait :processing do
        status { "processing" }
      end
      
      trait :needs_communication do
        status { "needs_communication" }
      end
      
      trait :approved do
        status { "approved" }
        resolution_summary { "测试解决方案" }
      end
      
      trait :rejected do
        status { "rejected" }
        resolution_summary { "测试拒绝原因" }
      end
    end
  end
end