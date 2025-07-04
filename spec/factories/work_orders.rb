# spec/factories/work_orders.rb
FactoryBot.define do
  factory :work_order do
    association :reimbursement
    association :creator, factory: :admin_user
    status { "pending" } # 默认状态
    
    # 共享字段
    problem_type { nil }
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
      
      # 覆盖基类的 initialize_with
      initialize_with { CommunicationWorkOrder.new }
      
      # 添加回调以设置fee_detail_ids_to_select
      after(:build) do |communication_work_order, evaluator|
        # 如果没有设置fee_detail_ids_to_select，则设置一个空数组
        communication_work_order.instance_variable_set('@fee_detail_ids_to_select', []) unless communication_work_order.instance_variable_get('@fee_detail_ids_to_select')
      end

      # Add WorkOrderFeeDetail records after creation if fee_details are associated
      after(:create) do |communication_work_order, evaluator|
        if communication_work_order.fee_details.present?
          communication_work_order.fee_details.each do |fee_detail|
            WorkOrderFeeDetail.find_or_create_by(
              fee_detail: fee_detail,
              work_order_id: communication_work_order.id
            )
          end
        end
      end

      trait :processing do
        status { "processing" }
      end
      
      trait :needs_communication do
        needs_communication { true }
      end
      
      trait :approved do
        status { "approved" }
        resolution_summary { "测试解决方案" }
      end
      
      trait :rejected do
        status { "rejected" }
        resolution_summary { "测试拒绝原因" }
        association :problem_type, factory: :problem_type
      end
    end
  end
end