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
        problem_type { "documentation_issue" }
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
        problem_type { "documentation_issue" }
      end
    end
  end

  # Add simple validation tests for the subclass factories
  RSpec.describe "WorkOrder subclass factories" do
    it "express_receipt_work_order is valid" do
      reimbursement = create(:reimbursement)
      creator = create(:admin_user)
      expect(build(:express_receipt_work_order, reimbursement: reimbursement, creator: creator)).to be_valid
    end

    it "audit_work_order is valid" do
      reimbursement = create(:reimbursement)
      creator = create(:admin_user)
      expect(build(:audit_work_order, reimbursement: reimbursement, creator: creator)).to be_valid
    end

    it "communication_work_order is valid" do
      reimbursement = create(:reimbursement)
      creator = create(:admin_user)
      expect(build(:communication_work_order, reimbursement: reimbursement, creator: creator)).to be_valid
    end

    # Test traits for AuditWorkOrder
    it "audit_work_order with processing trait is valid" do
      reimbursement = create(:reimbursement)
      creator = create(:admin_user)
      expect(build(:audit_work_order, :processing, reimbursement: reimbursement, creator: creator)).to be_valid
    end

    it "audit_work_order with approved trait is valid" do
      reimbursement = create(:reimbursement)
      creator = create(:admin_user)
      expect(build(:audit_work_order, :approved, reimbursement: reimbursement, creator: creator)).to be_valid
    end

    it "audit_work_order with rejected trait is valid" do
      reimbursement = create(:reimbursement)
      creator = create(:admin_user)
      expect(build(:audit_work_order, :rejected, reimbursement: reimbursement, creator: creator)).to be_valid
    end

    # Test traits for CommunicationWorkOrder
    it "communication_work_order with processing trait is valid" do
      reimbursement = create(:reimbursement)
      creator = create(:admin_user)
      expect(build(:communication_work_order, :processing, reimbursement: reimbursement, creator: creator)).to be_valid
    end

    # needs_communication is now correctly implemented as a boolean flag
    it "communication_work_order with needs_communication trait is valid" do
      reimbursement = create(:reimbursement)
      creator = create(:admin_user)
      expect(build(:communication_work_order, :needs_communication, reimbursement: reimbursement, creator: creator)).to be_valid
    end

    it "communication_work_order with approved trait is valid" do
      reimbursement = create(:reimbursement)
      creator = create(:admin_user)
      expect(build(:communication_work_order, :approved, reimbursement: reimbursement, creator: creator)).to be_valid
    end

    it "communication_work_order with rejected trait is valid" do
      reimbursement = create(:reimbursement)
      creator = create(:admin_user)
      expect(build(:communication_work_order, :rejected, reimbursement: reimbursement, creator: creator)).to be_valid
    end
  end
end