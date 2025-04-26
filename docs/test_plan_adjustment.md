# SCI2 工单系统测试计划调整

## 1. 概述

本文档基于改进的独立拆表设计方案，对原有的测试计划进行调整。新的设计方案将原来基于STI的单表设计改为独立拆表模式，为每种工单类型创建独立的表，同时简化关联关系。这些变化需要对测试策略和测试用例进行相应的调整。

## 2. 测试策略调整

### 2.1 测试结构调整

原测试结构：
```
test/
├── models/
│   ├── work_order_test.rb (包含所有工单类型的测试)
│   └── ...
```

调整后的测试结构：
```
test/
├── models/
│   ├── express_receipt_work_order_test.rb
│   ├── audit_work_order_test.rb
│   ├── communication_work_order_test.rb
│   └── ...
```

### 2.2 测试辅助方法调整

需要调整测试辅助方法，以适应新的表结构和关联关系：

```ruby
# test/test_helper.rb

# 创建快递收单工单
def create_express_receipt_work_order(reimbursement, attributes = {})
  ExpressReceiptWorkOrder.create!({
    reimbursement_id: reimbursement.id,
    status: 'received',
    tracking_number: "SF-TEST-#{Time.now.to_i}",
    received_at: Time.current,
    created_by: @admin_user&.id || 1
  }.merge(attributes))
end

# 创建审核工单
def create_audit_work_order(reimbursement, express_work_order = nil, attributes = {})
  AuditWorkOrder.create!({
    reimbursement_id: reimbursement.id,
    express_receipt_work_order_id: express_work_order&.id,
    status: 'pending',
    created_by: @admin_user&.id || 1
  }.merge(attributes))
end

# 创建沟通工单
def create_communication_work_order(reimbursement, audit_work_order, attributes = {})
  CommunicationWorkOrder.create!({
    reimbursement_id: reimbursement.id,
    audit_work_order_id: audit_work_order.id,
    status: 'open',
    created_by: @admin_user&.id || 1
  }.merge(attributes))
end

# 创建费用明细选择
def create_fee_detail_selection(fee_detail, attributes = {})
  FeeDetailSelection.create!({
    fee_detail_id: fee_detail.id,
    verification_status: 'pending'
  }.merge(attributes))
end
```

### 2.3 测试数据准备调整

需要调整测试数据准备方法，以适应新的表结构：

```ruby
# test/fixtures/express_receipt_work_orders.yml
express_wo_one:
  reimbursement: reimbursement_one
  status: received
  tracking_number: SF123456789
  received_at: <%= Time.current %>
  created_by: 1

express_wo_two:
  reimbursement: reimbursement_two
  status: processed
  tracking_number: SF987654321
  received_at: <%= Time.current - 1.day %>
  created_by: 1

# test/fixtures/audit_work_orders.yml
audit_wo_one:
  reimbursement: reimbursement_one
  express_receipt_work_order: express_wo_one
  status: pending
  created_by: 1

audit_wo_two:
  reimbursement: reimbursement_two
  status: processing
  created_by: 1

# test/fixtures/communication_work_orders.yml
communication_wo_one:
  reimbursement: reimbursement_one
  audit_work_order: audit_wo_one
  status: open
  created_by: 1

communication_wo_two:
  reimbursement: reimbursement_two
  audit_work_order: audit_wo_two
  status: in_progress
  created_by: 1
```

## 3. 测试用例调整

### 3.1 单元测试调整

#### 3.1.1 快递收单工单测试

```ruby
# test/models/express_receipt_work_order_test.rb
require 'test_helper'

class ExpressReceiptWorkOrderTest < ActiveSupport::TestCase
  setup do
    @reimbursement = reimbursements(:reimbursement_one)
    @work_order = create_express_receipt_work_order(@reimbursement)
  end
  
  test "express receipt work order basic status flow" do
    assert_equal "received", @work_order.status
    
    # 处理快递收单
    @work_order.process
    assert_equal "processed", @work_order.status
    
    # 完成处理
    @work_order.complete
    assert_equal "completed", @work_order.status
    
    # 验证创建审核工单
    audit_work_order = AuditWorkOrder.find_by(express_receipt_work_order_id: @work_order.id)
    assert_not_nil audit_work_order
    assert_equal "pending", audit_work_order.status
  end
  
  test "express receipt work order status change records" do
    assert_equal "received", @work_order.status
    
    # 执行状态变更
    assert_difference 'WorkOrderStatusChange.count', 1 do
      @work_order.process
    end
    
    # 验证状态变更记录
    change = WorkOrderStatusChange.last
    assert_equal "express_receipt", change.work_order_type
    assert_equal @work_order.id, change.work_order_id
    assert_equal "received", change.from_status
    assert_equal "processed", change.to_status
  end
end
```

#### 3.1.2 审核工单测试

```ruby
# test/models/audit_work_order_test.rb
require 'test_helper'

class AuditWorkOrderTest < ActiveSupport::TestCase
  setup do
    @reimbursement = reimbursements(:reimbursement_one)
    @work_order = create_audit_work_order(@reimbursement)
  end
  
  test "audit work order basic status flow - approval path" do
    assert_equal "pending", @work_order.status
    
    # 开始处理
    @work_order.start_processing
    assert_equal "processing", @work_order.status
    
    # 开始审核
    @work_order.start_audit
    assert_equal "auditing", @work_order.status
    
    # 审核通过
    @work_order.approve
    assert_equal "approved", @work_order.status
    
    # 完成处理
    @work_order.complete
    assert_equal "completed", @work_order.status
  end
  
  test "audit work order needs communication and creating communication work order" do
    assert_equal "pending", @work_order.status
    
    # 开始处理
    @work_order.start_processing
    assert_equal "processing", @work_order.status
    
    # 开始审核
    @work_order.start_audit
    assert_equal "auditing", @work_order.status
    
    # 需要沟通并创建沟通工单
    assert_difference 'CommunicationWorkOrder.count', 1 do
      @work_order.create_communication_work_order(description: "测试沟通")
    end
    
    assert_equal "needs_communication", @work_order.status
    
    # 验证创建的沟通工单
    communication_work_order = CommunicationWorkOrder.last
    assert_equal "open", communication_work_order.status
    assert_equal @work_order.id, communication_work_order.audit_work_order_id
  end
end
```

#### 3.1.3 沟通工单测试

```ruby
# test/models/communication_work_order_test.rb
require 'test_helper'

class CommunicationWorkOrderTest < ActiveSupport::TestCase
  setup do
    @reimbursement = reimbursements(:reimbursement_one)
    @audit_work_order = create_audit_work_order(@reimbursement)
    @audit_work_order.start_processing
    @audit_work_order.start_audit
    @audit_work_order.need_communication
    @work_order = create_communication_work_order(@reimbursement, @audit_work_order)
  end
  
  test "communication work order basic status flow - resolved path" do
    assert_equal "open", @work_order.status
    
    # 开始沟通
    @work_order.start_communication
    assert_equal "in_progress", @work_order.status
    
    # 添加沟通记录
    @work_order.add_communication_record(
      communicator_role: "Finance",
      communicator_name: "Test User",
      content: "测试沟通内容",
      communication_method: "system"
    )
    
    # 解决问题
    @work_order.resolve("问题已解决")
    assert_equal "resolved", @work_order.status
    
    # 验证通知父工单
    @audit_work_order.reload
    assert_equal "auditing", @audit_work_order.status
    
    # 关闭工单
    @work_order.close
    assert_equal "closed", @work_order.status
  end
  
  test "communication work order with fee detail selections" do
    # 创建费用明细
    fee_detail = create_test_fee_detail(@reimbursement)
    
    # 关联费用明细到沟通工单
    selection = FeeDetailSelection.create!(
      communication_work_order_id: @work_order.id,
      fee_detail_id: fee_detail.id,
      verification_status: 'pending'
    )
    
    # 验证关联成功
    assert_equal 1, @work_order.fee_detail_selections.count
    assert_equal fee_detail.id, @work_order.fee_detail_selections.first.fee_detail_id
  end
end
```

### 3.2 集成测试调整

#### 3.2.1 完整工作流测试

```ruby
# test/integration/complete_workflow_test.rb
require 'test_helper'

class CompleteWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    # 清理数据
    ExpressReceiptWorkOrder.delete_all
    AuditWorkOrder.delete_all
    CommunicationWorkOrder.delete_all
    Reimbursement.delete_all
    FeeDetail.delete_all
    
    @admin_user = create_admin_user
    sign_in @admin_user
  end
  
  test "complete reimbursement flow from express receipt to audit completion" do
    # 创建测试数据
    reimbursement = Reimbursement.create!(
      invoice_number: "ER-INT-001",
      document_name: "Integration Test Reimbursement 1",
      applicant: "Test Applicant 1",
      is_electronic: false,
      status: 'pending',
      receipt_status: 'pending',
      amount: 100.0
    )
    
    # 创建快递收单工单
    express_work_order = create_express_receipt_work_order(reimbursement, {
      tracking_number: "SF-INT-001",
      received_at: Time.current
    })
    
    # 处理快递收单工单
    express_work_order.process
    express_work_order.complete
    assert_equal 'completed', express_work_order.reload.status
    
    # 验证自动创建审核工单
    audit_work_order = AuditWorkOrder.find_by(express_receipt_work_order_id: express_work_order.id)
    assert_not_nil audit_work_order
    assert_equal express_work_order.id, audit_work_order.express_receipt_work_order_id
    
    # 处理审核工单
    audit_work_order.start_processing
    audit_work_order.start_audit
    audit_work_order.approve
    audit_work_order.complete
    assert_equal 'completed', audit_work_order.reload.status
    
    # 验证工单状态
    express_work_order.reload
    audit_work_order.reload
    assert_equal "completed", express_work_order.status
    assert_equal "completed", audit_work_order.status
  end
  
  test "complete reimbursement flow with issue handling" do
    # 创建测试数据
    reimbursement = Reimbursement.create!(
      invoice_number: "ER-INT-002",
      document_name: "Integration Test Reimbursement 2",
      applicant: "Test Applicant 2",
      is_electronic: false,
      status: 'pending',
      receipt_status: 'pending',
      amount: 500.0
    )
    
    # 创建费用明细
    fee_detail = FeeDetail.create!(
      reimbursement: reimbursement,
      document_number: reimbursement.invoice_number,
      fee_type: "交通费",
      amount: 150.0,
      verification_status: 'pending'
    )
    
    # 创建快递收单工单
    express_work_order = create_express_receipt_work_order(reimbursement, {
      tracking_number: "SF-INT-002",
      received_at: Time.current
    })
    
    # 处理快递收单工单
    express_work_order.process
    express_work_order.complete
    
    # 获取创建的审核工单
    audit_work_order = AuditWorkOrder.find_by(express_receipt_work_order_id: express_work_order.id)
    
    # 关联费用明细
    selection = FeeDetailSelection.create!(
      audit_work_order_id: audit_work_order.id,
      fee_detail_id: fee_detail.id,
      verification_status: 'pending'
    )
    
    # 处理审核工单至需要沟通状态
    audit_work_order.start_processing
    audit_work_order.start_audit
    
    # 创建沟通工单
    communication_work_order = nil
    assert_difference 'CommunicationWorkOrder.count', 1 do
      communication_work_order = audit_work_order.create_communication_work_order(
        description: "发票金额与报销金额不符"
      )
    end
    assert_equal 'needs_communication', audit_work_order.reload.status
    
    # 关联费用明细到沟通工单
    FeeDetailSelection.create!(
      communication_work_order_id: communication_work_order.id,
      fee_detail_id: fee_detail.id,
      verification_status: 'pending'
    )
    
    # 处理沟通工单
    communication_work_order.start_communication
    
    # 添加沟通记录
    record1 = communication_work_order.add_communication_record(
      communicator_role: "Finance",
      communicator_name: @admin_user.email,
      content: "请提供正确的发票",
      communication_method: "system"
    )
    
    # 添加回复记录
    record2 = communication_work_order.add_communication_record(
      communicator_role: "Applicant",
      communicator_name: "申请人姓名",
      content: "已提供正确的发票",
      communication_method: "system"
    )
    
    # 解决问题
    communication_work_order.resolve("问题已解决，收到正确发票")
    communication_work_order.close
    
    # 验证审核工单状态恢复
    assert_equal 'auditing', audit_work_order.reload.status
    
    # 完成审核工单
    audit_work_order.approve
    audit_work_order.complete
    
    # 验证最终状态
    assert_equal "completed", express_work_order.reload.status
    assert_equal "completed", audit_work_order.reload.status
    assert_equal "closed", communication_work_order.reload.status
  end
end
```

### 3.3 数据导入测试调整

```ruby
# test/integration/data_import_test.rb
require 'test_helper'

class ExpressReceiptImportTest < ActionDispatch::IntegrationTest
  include ImportTestHelper
  
  setup do
    @reimbursement = reimbursements(:reimbursement_one)
  end
  
  test "should import express receipts and create work orders" do
    file = import_test_file('matching_express_receipts')
    
    assert_difference 'ExpressReceipt.count', 1 do
      assert_difference 'ExpressReceiptWorkOrder.count', 1 do
        post admin_express_receipts_import_path, params: { file: file }
      end
    end
    
    # 验证创建的工单
    work_order = ExpressReceiptWorkOrder.last
    assert_equal @reimbursement.id, work_order.reimbursement_id
    assert_equal "received", work_order.status
    
    # 验证更新报销单状态
    @reimbursement.reload
    assert_equal "received", @reimbursement.receipt_status
  end
end
```

## 4. 测试环境配置调整

### 4.1 数据库清理策略

由于现在有多个工单表，需要确保测试前后清理所有相关表：

```ruby
# test/test_helper.rb
setup do
  # 清理所有工单相关表
  ExpressReceiptWorkOrder.delete_all
  AuditWorkOrder.delete_all
  CommunicationWorkOrder.delete_all
  FeeDetailSelection.delete_all
  CommunicationRecord.delete_all
  WorkOrderStatusChange.delete_all
  
  # 清理其他相关表
  Reimbursement.delete_all
  ExpressReceipt.delete_all
  FeeDetail.delete_all
  OperationHistory.delete_all
  
  # 清理用户表
  User.delete_all
  AdminUser.delete_all
end
```

### 4.2 测试数据库迁移

需要确保测试环境中的数据库迁移与新的表结构一致：

```ruby
# 创建测试数据库迁移脚本
rails g migration CreateExpressReceiptWorkOrders
rails g migration CreateAuditWorkOrders
rails g migration CreateCommunicationWorkOrders
rails g migration UpdateFeeDetailSelections
```

## 5. 测试执行计划调整

原测试执行计划需要调整以适应新的设计：

### 5.1 阶段一：数据结构测试（1周）

- 测试新的表结构
- 测试表之间的关联关系
- 测试数据库约束和索引

### 5.2 阶段二：模型单元测试（1周）

- 测试各工单类型的模型
- 测试状态流转逻辑
- 测试关联关系和验证

### 5.3 阶段三：服务对象测试（1周）

- 测试数据导入服务
- 测试工单创建和处理服务
- 测试费用明细验证服务

### 5.4 阶段四：集成测试（1周）

- 测试完整业务流程
- 测试多个组件之间的交互
- 测试边界条件和异常情况

### 5.5 阶段五：系统测试（1周）

- 测试用户界面和交互
- 测试完整的用户场景
- 性能测试和负载测试

## 6. 总结

通过以上调整，测试计划将与新的独立拆表设计保持一致。这些调整主要包括：

1. 将单一的工单测试拆分为多个独立的工单类型测试
2. 调整测试辅助方法以适应新的表结构和关联关系
3. 更新测试数据准备方法
4. 调整集成测试以反映新的工单关联方式
5. 更新测试环境配置和数据库清理策略

这些调整将确保测试覆盖所有新设计的功能和关联关系，同时保持测试的可维护性和可扩展性。