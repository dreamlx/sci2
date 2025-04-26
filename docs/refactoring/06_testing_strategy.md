# SCI2 工单系统测试策略

## 1. 测试概述

测试是确保系统质量和功能正确性的关键环节。在SCI2工单系统的重构过程中，我们将采用多层次的测试策略，包括单元测试、集成测试和系统测试，以确保系统的各个组件和整体功能都能正常工作。

### 1.1 测试目标

1. **验证功能正确性**：确保系统的各个功能按照预期工作
2. **保证数据一致性**：确保数据在各个处理环节中保持一致
3. **验证业务流程**：确保工单处理流程符合业务需求
4. **测试边界条件**：确保系统在各种边界条件下能够正常工作
5. **性能测试**：确保系统在预期负载下能够正常运行

### 1.2 测试环境

1. **开发环境**：用于开发人员进行单元测试和基本功能测试
2. **测试环境**：用于QA团队进行集成测试和系统测试
3. **预生产环境**：用于进行最终的验收测试和性能测试

## 2. 单元测试

单元测试是测试策略的基础，用于测试系统中的最小可测试单元。在SCI2工单系统中，我们将为模型、服务和控制器编写单元测试。

### 2.1 模型测试

```ruby
# test/models/reimbursement_test.rb
require 'test_helper'

class ReimbursementTest < ActiveSupport::TestCase
  setup do
    @reimbursement = reimbursements(:valid_reimbursement)
  end
  
  test "should be valid" do
    assert @reimbursement.valid?
  end
  
  test "should require invoice_number" do
    @reimbursement.invoice_number = nil
    assert_not @reimbursement.valid?
  end
  
  test "should have unique invoice_number" do
    duplicate = @reimbursement.dup
    assert_not duplicate.valid?
  end
  
  test "should mark as received" do
    @reimbursement.mark_as_received
    assert_equal "received", @reimbursement.receipt_status
    assert_not_nil @reimbursement.receipt_date
  end
  
  test "should mark as complete" do
    @reimbursement.mark_as_complete
    assert @reimbursement.is_complete
    assert_equal "closed", @reimbursement.reimbursement_status
  end
end
```

### 2.2 工单模型测试

#### 2.2.1 快递收单工单测试

```ruby
# test/models/express_receipt_work_order_test.rb
require 'test_helper'

class ExpressReceiptWorkOrderTest < ActiveSupport::TestCase
  setup do
    @work_order = express_receipt_work_orders(:received)
  end
  
  test "should be valid" do
    assert @work_order.valid?
  end
  
  test "should require tracking_number" do
    @work_order.tracking_number = nil
    assert_not @work_order.valid?
  end
  
  test "should process" do
    assert @work_order.process
    assert_equal "processed", @work_order.status
  end
  
  test "should complete" do
    @work_order.status = "processed"
    assert @work_order.complete
    assert_equal "completed", @work_order.status
  end
  
  test "should create audit work order after complete" do
    @work_order.status = "processed"
    assert_difference 'AuditWorkOrder.count' do
      @work_order.complete
    end
    
    audit_work_order = AuditWorkOrder.last
    assert_equal @work_order.reimbursement_id, audit_work_order.reimbursement_id
    assert_equal @work_order.id, audit_work_order.express_receipt_work_order_id
    assert_equal "pending", audit_work_order.status
  end
end
```

#### 2.2.2 审核工单测试

```ruby
# test/models/audit_work_order_test.rb
require 'test_helper'

class AuditWorkOrderTest < ActiveSupport::TestCase
  setup do
    @work_order = audit_work_orders(:pending)
  end
  
  test "should be valid" do
    assert @work_order.valid?
  end
  
  test "should start processing" do
    assert @work_order.start_processing
    assert_equal "processing", @work_order.status
  end
  
  test "should start audit" do
    @work_order.status = "processing"
    assert @work_order.start_audit
    assert_equal "auditing", @work_order.status
  end
  
  test "should approve" do
    @work_order.status = "auditing"
    assert @work_order.approve
    assert_equal "approved", @work_order.status
    assert_equal "approved", @work_order.audit_result
    assert_not_nil @work_order.audit_date
  end
  
  test "should reject" do
    @work_order.status = "auditing"
    assert @work_order.reject
    assert_equal "rejected", @work_order.status
    assert_equal "rejected", @work_order.audit_result
    assert_not_nil @work_order.audit_date
  end
  
  test "should need communication" do
    @work_order.status = "auditing"
    assert @work_order.need_communication
    assert_equal "needs_communication", @work_order.status
  end
  
  test "should resume audit" do
    @work_order.status = "needs_communication"
    assert @work_order.resume_audit
    assert_equal "auditing", @work_order.status
  end
  
  test "should complete" do
    @work_order.status = "approved"
    assert @work_order.complete
    assert_equal "completed", @work_order.status
  end
  
  test "should create communication work order" do
    @work_order.status = "auditing"
    
    assert_difference 'CommunicationWorkOrder.count' do
      @work_order.create_communication_work_order(
        communication_method: "email",
        initiator_role: "auditor"
      )
    end
    
    assert_equal "needs_communication", @work_order.status
    
    comm_order = CommunicationWorkOrder.last
    assert_equal @work_order.reimbursement_id, comm_order.reimbursement_id
    assert_equal @work_order.id, comm_order.audit_work_order_id
    assert_equal "open", comm_order.status
  end
end
#### 2.2.3 沟通工单测试

```ruby
# test/models/communication_work_order_test.rb
require 'test_helper'

class CommunicationWorkOrderTest < ActiveSupport::TestCase
  setup do
    @work_order = communication_work_orders(:open)
  end
  
  test "should be valid" do
    assert @work_order.valid?
  end
  
  test "should start communication" do
    assert @work_order.start_communication
    assert_equal "in_progress", @work_order.status
  end
  
  test "should resolve" do
    @work_order.status = "in_progress"
    assert @work_order.resolve
    assert_equal "resolved", @work_order.status
  end
  
  test "should mark unresolved" do
    @work_order.status = "in_progress"
    assert @work_order.mark_unresolved
    assert_equal "unresolved", @work_order.status
  end
  
  test "should close" do
    @work_order.status = "resolved"
    assert @work_order.close
    assert_equal "closed", @work_order.status
  end
  
  test "should add communication record" do
    assert_difference 'CommunicationRecord.count' do
      @work_order.add_communication_record(
        content: "测试沟通内容",
        communicator_role: "auditor",
        communicator_name: "测试人员",
        communication_method: "system"
      )
    end
    
    record = CommunicationRecord.last
    assert_equal @work_order.id, record.communication_work_order_id
    assert_equal "测试沟通内容", record.content
    assert_equal "auditor", record.communicator_role
  end
  
  test "should notify parent work order after resolve" do
    @work_order.status = "in_progress"
    @work_order.audit_work_order.update(status: "needs_communication")
    
    @work_order.resolve
    
    assert_equal "auditing", @work_order.audit_work_order.reload.status
  end
end
```

### 2.3 服务测试

#### 2.3.1 导入服务测试

```ruby
# test/services/reimbursement_import_service_test.rb
require 'test_helper'

class ReimbursementImportServiceTest < ActiveSupport::TestCase
  setup do
    @admin_user = admin_users(:admin)
    @file = fixture_file_upload('test_reimbursements.csv', 'text/csv')
  end
  
  test "should import reimbursements" do
    service = ReimbursementImportService.new(@file, @admin_user)
    result = service.import
    
    assert result[:success]
    assert_equal 2, result[:created]
    assert_equal 1, result[:updated]
    assert_equal 0, result[:errors]
  end
  
  test "should handle invalid file" do
    service = ReimbursementImportService.new(nil, @admin_user)
    result = service.import
    
    assert_not result[:success]
    assert_includes result[:errors], "文件不存在"
  end
  
  test "should create audit work order for non-electronic reimbursement" do
    assert_difference 'AuditWorkOrder.count' do
      service = ReimbursementImportService.new(@file, @admin_user)
      service.import
    end
  end
end
```

#### 2.3.2 工单处理服务测试

```ruby
# test/services/audit_work_order_service_test.rb
require 'test_helper'

class AuditWorkOrderServiceTest < ActiveSupport::TestCase
  setup do
    @admin_user = admin_users(:admin)
    @work_order = audit_work_orders(:pending)
    @service = AuditWorkOrderService.new(@work_order, @admin_user)
  end
  
  test "should start processing" do
    assert @service.start_processing
    assert_equal "processing", @work_order.reload.status
  end
  
  test "should approve with comment" do
    @work_order.update(status: "auditing")
    
    assert @service.approve("审核通过")
    assert_equal "approved", @work_order.reload.status
    assert_equal "approved", @work_order.audit_result
    assert_equal "审核通过", @work_order.audit_comment
  end
  
  test "should update fee details after approve" do
    @work_order.update(status: "auditing")
    
    # 创建关联的费用明细
    fee_detail = fee_details(:pending)
    @work_order.select_fee_detail(fee_detail)
    
    @service.approve
    
    assert_equal "verified", fee_detail.reload.verification_status
  end
  
  test "should create communication work order" do
    @work_order.update(status: "auditing")
    
    assert_difference 'CommunicationWorkOrder.count' do
      @service.create_communication_work_order(
        communication_method: "email",
        initiator_role: "auditor",
        content: "需要沟通"
      )
    end
    
    assert_equal "needs_communication", @work_order.reload.status
    
    comm_order = CommunicationWorkOrder.last
    assert_equal 1, comm_order.communication_records.count
    assert_equal "需要沟通", comm_order.communication_records.first.content
  end
end
```

```ruby
# test/services/communication_work_order_service_test.rb
require 'test_helper'

class CommunicationWorkOrderServiceTest < ActiveSupport::TestCase
  setup do
    @admin_user = admin_users(:admin)
    @work_order = communication_work_orders(:open)
    @service = CommunicationWorkOrderService.new(@work_order, @admin_user)
  end
  
  test "should start communication" do
    assert @service.start_communication
    assert_equal "in_progress", @work_order.reload.status
  end
  
  test "should resolve with summary" do
    @work_order.update(status: "in_progress")
    
    assert @service.resolve("问题已解决")
    assert_equal "resolved", @work_order.reload.status
    assert_equal "问题已解决", @work_order.resolution_summary
  end
  
  test "should add communication record" do
    assert_difference 'CommunicationRecord.count' do
      @service.add_communication_record(
        content: "测试沟通内容",
        communicator_role: "auditor",
        communication_method: "email"
      )
    end
    
    record = CommunicationRecord.last
    assert_equal @work_order.id, record.communication_work_order_id
    assert_equal "测试沟通内容", record.content
    assert_equal "auditor", record.communicator_role
    assert_equal @admin_user.email, record.communicator_name
  end
end
```

## 3. 集成测试

集成测试用于测试多个组件之间的交互，确保它们能够协同工作。在SCI2工单系统中，我们将重点测试工单流程和数据导入流程。

test "complete audit work order flow" do
    # 创建审核工单
    audit_work_order = AuditWorkOrder.create!(
      reimbursement: @reimbursement,
      status: "pending",
      created_by: @admin_user.id
    )
    
    # 创建费用明细
    fee_detail = FeeDetail.create!(
      document_number: @reimbursement.invoice_number,
      fee_type: "交通费",
      amount: 100,
      currency: "CNY",
      verification_status: "pending"
    )
    
    # 关联费用明细
    audit_work_order.select_fee_detail(fee_detail)
    
    # 开始处理
    put start_processing_admin_audit_work_order_path(audit_work_order)
    assert_redirected_to admin_audit_work_order_path(audit_work_order)
    assert_equal "processing", audit_work_order.reload.status
    
    # 开始审核
    put start_audit_admin_audit_work_order_path(audit_work_order)
    assert_redirected_to admin_audit_work_order_path(audit_work_order)
    assert_equal "auditing", audit_work_order.reload.status
    
    # 审核通过
    post do_approve_admin_audit_work_order_path(audit_work_order), params: { comment: "审核通过" }
    assert_redirected_to admin_audit_work_order_path(audit_work_order)
    assert_equal "approved", audit_work_order.reload.status
    assert_equal "approved", audit_work_order.audit_result
    
    # 完成审核
    put complete_admin_audit_work_order_path(audit_work_order)
    assert_redirected_to admin_audit_work_order_path(audit_work_order)
    assert_equal "completed", audit_work_order.reload.status
    
    # 验证费用明细状态
    assert_equal "verified", fee_detail.reload.verification_status
  end
  
  test "communication work order flow" do
    # 创建审核工单
    audit_work_order = AuditWorkOrder.create!(
      reimbursement: @reimbursement,
      status: "auditing",
      created_by: @admin_user.id
    )
    
    # 创建沟通工单
    post create_communication_admin_audit_work_order_path(audit_work_order), params: {
      communication_method: "email",
      initiator_role: "auditor",
      content: "需要沟通"
    }
    
    communication_work_order = CommunicationWorkOrder.last
    assert_redirected_to admin_communication_work_order_path(communication_work_order)
    assert_equal "open", communication_work_order.status
    assert_equal "needs_communication", audit_work_order.reload.status
    
    # 开始沟通
    put start_communication_admin_communication_work_order_path(communication_work_order)
    assert_redirected_to admin_communication_work_order_path(communication_work_order)
    assert_equal "in_progress", communication_work_order.reload.status
    
    # 添加沟通记录
    post create_communication_record_admin_communication_work_order_path(communication_work_order), params: {
      content: "已沟通",
      communicator_role: "auditor",
      communicator_name: @admin_user.email,
      communication_method: "email"
    }
    
    assert_redirected_to admin_communication_work_order_path(communication_work_order)
    assert_equal 2, communication_work_order.communication_records.count
    
    # 标记已解决
    post do_resolve_admin_communication_work_order_path(communication_work_order), params: {
      resolution_summary: "问题已解决"
    }
    
    assert_redirected_to admin_communication_work_order_path(communication_work_order)
    assert_equal "resolved", communication_work_order.reload.status
    assert_equal "auditing", audit_work_order.reload.status
    
    # 关闭沟通工单
    put close_admin_communication_work_order_path(communication_work_order)
    assert_redirected_to admin_communication_work_order_path(communication_work_order)
    assert_equal "closed", communication_work_order.reload.status
  end
end
```

### 3.2 数据导入测试

```ruby
# test/integration/data_import_test.rb
require 'test_helper'

class DataImportTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = admin_users(:admin)
    sign_in @admin_user
  end
  
  test "import reimbursements" do
    file = fixture_file_upload('test_reimbursements.csv', 'text/csv')
    
    assert_difference 'Reimbursement.count', 2 do
      post import_admin_reimbursements_path, params: { file: file }
    end
    
    assert_redirected_to admin_reimbursements_path
  end
  
  test "import express receipts" do
    # 先导入报销单
    reimbursement_file = fixture_file_upload('test_reimbursements.csv', 'text/csv')
    post import_admin_reimbursements_path, params: { file: reimbursement_file }
    
    # 导入快递收单
    express_receipt_file = fixture_file_upload('test_express_receipts.csv', 'text/csv')
    
    assert_difference 'ExpressReceipt.count', 2 do
      assert_difference 'ExpressReceiptWorkOrder.count', 2 do
        post import_admin_express_receipts_path, params: { file: express_receipt_file }
      end
    end
    
    assert_redirected_to admin_express_receipts_path
    
    # 验证报销单状态是否更新
    reimbursement = Reimbursement.find_by(invoice_number: "R20250101001")
    assert_equal "received", reimbursement.receipt_status
    assert_not_nil reimbursement.receipt_date
  end
  
  test "import fee details" do
    # 先导入报销单
    reimbursement_file = fixture_file_upload('test_reimbursements.csv', 'text/csv')
    post import_admin_reimbursements_path, params: { file: reimbursement_file }
    
    # 创建审核工单
    reimbursement = Reimbursement.first
    audit_work_order = AuditWorkOrder.create!(
      reimbursement: reimbursement,
      status: "pending",
      created_by: @admin_user.id
    )
    
    # 导入费用明细
    fee_detail_file = fixture_file_upload('test_fee_details.csv', 'text/csv')
    
    assert_difference 'FeeDetail.count', 3 do
      assert_difference 'FeeDetailSelection.count', 3 do
        post import_admin_fee_details_path, params: { file: fee_detail_file }
      end
    end
    
    assert_redirected_to admin_fee_details_path
    
    # 验证费用明细是否关联到审核工单
    assert_equal 3, audit_work_order.fee_details.count
  end
  
  test "import operation histories" do
    # 先导入报销单
    reimbursement_file = fixture_file_upload('test_reimbursements.csv', 'text/csv')
    post import_admin_reimbursements_path, params: { file: reimbursement_file }
    
    # 创建审核工单
    reimbursement = Reimbursement.first
    audit_work_order = AuditWorkOrder.create!(
      reimbursement: reimbursement,
      status: "auditing",
      created_by: @admin_user.id
    )
    
    # 导入操作历史
    operation_history_file = fixture_file_upload('test_operation_histories.csv', 'text/csv')
    
    assert_difference 'OperationHistory.count', 2 do
      post import_admin_operation_histories_path, params: { file: operation_history_file }
    end
    
    assert_redirected_to admin_operation_histories_path
    
    # 验证报销单状态是否更新
    assert reimbursement.reload.is_complete
    assert_equal "closed", reimbursement.reimbursement_status
    
    # 验证审核工单状态是否更新
    assert_equal "completed", audit_work_order.reload.status
  end
end
```

### 3.3 费用明细验证测试

```ruby
# test/integration/fee_detail_verification_test.rb
require 'test_helper'

class FeeDetailVerificationTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = admin_users(:admin)
    sign_in @admin_user
    
    @reimbursement = reimbursements(:valid_reimbursement)
    @audit_work_order = audit_work_orders(:auditing)
    @audit_work_order.update(reimbursement: @reimbursement)
    
    @fee_detail = fee_details(:pending)
    @fee_detail.update(document_number: @reimbursement.invoice_number)
    
    @audit_work_order.select_fee_detail(@fee_detail)
  end
  
  test "verify fee detail" do
    post verify_admin_fee_detail_path(@fee_detail), params: {
      work_order_id: @audit_work_order.id,
      verification_status: "verified",
      comment: "验证通过"
    }
    
    assert_redirected_to admin_audit_work_order_path(@audit_work_order)
    assert_equal "verified", @fee_detail.reload.verification_status
    
    selection = @audit_work_order.fee_detail_selections.find_by(fee_detail: @fee_detail)
    assert_equal "verified", selection.verification_status
    assert_equal "验证通过", selection.verification_comment
  end
  
  test "mark fee detail as problematic" do
    post mark_problematic_admin_fee_detail_path(@fee_detail), params: {
      work_order_id: @audit_work_order.id,
      issue_description: "金额有问题"
    }
    
    assert_redirected_to admin_communication_work_order_path(CommunicationWorkOrder.last)
    assert_equal "problematic", @fee_detail.reload.verification_status
    
    # 验证是否创建了沟通工单
    communication_work_order = CommunicationWorkOrder.last
    assert_not_nil communication_work_order
    assert_equal @audit_work_order.id, communication_work_order.audit_work_order_id
    
    # 验证费用明细是否关联到沟通工单
    assert_equal 1, communication_work_order.fee_details.count
    assert_equal @fee_detail.id, communication_work_order.fee_details.first.id
  end
  
  test "resolve fee detail issue" do
    # 先标记为有问题
    post mark_problematic_admin_fee_detail_path(@fee_detail), params: {
      work_order_id: @audit_work_order.id,
      issue_description: "金额有问题"
    }
    
    communication_work_order = CommunicationWorkOrder.last
    
    # 解决问题
    post resolve_issue_admin_fee_detail_path(@fee_detail), params: {
      work_order_id: communication_work_order.id,
      resolution: "问题已解决"
    }
    
    assert_redirected_to admin_communication_work_order_path(communication_work_order)
    
    # 验证费用明细选择记录是否更新
    selection = communication_work_order.fee_detail_selections.find_by(fee_detail: @fee_detail)
    assert_equal "问题已解决", selection.verification_comment
  end
end
```

## 4. 系统测试

系统测试用于测试整个系统的端到端功能，确保系统作为一个整体能够正常工作。在SCI2工单系统中，我们将使用Capybara进行系统测试。

```ruby
# test/system/complete_workflow_test.rb
require "application_system_test_case"

class CompleteWorkflowTest < ApplicationSystemTestCase
  setup do
    @admin_user = admin_users(:admin)
    login_as(@admin_user, scope: :admin_user)
  end
  
  test "complete workflow from import to completion" do
    # 导入报销单
    visit new_import_admin_reimbursements_path
    attach_file "file", file_fixture("test_reimbursements.csv")
    click_button "导入"
    
    assert_text "导入成功"
    
    # 导入快递收单
    visit new_import_admin_express_receipts_path
    attach_file "file", file_fixture("test_express_receipts.csv")
    click_button "导入"
    
    assert_text "导入成功"
    
    # 导入费用明细
    visit new_import_admin_fee_details_path
    attach_file "file", file_fixture("test_fee_details.csv")
    click_button "导入"
    
    assert_text "导入成功"
    
    # 处理快递收单工单
    visit admin_express_receipt_work_orders_path
    click_link "查看", match: :first
    
    click_link "处理"
    assert_text "工单已处理"
    
    click_link "完成"
    assert_text "工单已完成"
    
    # 处理审核工单
    visit admin_audit_work_orders_path
    click_link "查看", match: :first
    
    click_link "开始处理"
    assert_text "工单已开始处理"
    
    click_link "开始审核"
    assert_text "工单已开始审核"
    
    # 验证费用明细
    within "#fee_details" do
      click_link "验证", match: :first
    end
    
    select "已验证", from: "verification_status"
    fill_in "comment", with: "验证通过"
    click_button "提交"
    
    assert_text "费用明细已验证"
    
    # 标记费用明细有问题
    within "#fee_details" do
      click_link "标记问题", match: :first
    end
    
    fill_in "issue_description", with: "金额有问题"
    click_button "提交"
    
    assert_text "沟通工单已创建"
    
    # 处理沟通工单
    click_link "开始沟通"
    assert_text "工单已开始沟通"
    
    click_link "添加沟通记录"
    fill_in "content", with: "已与申请人沟通"
    select "审核人", from: "communicator_role"
    select "邮件", from: "communication_method"
    click_button "添加记录"
    
    assert_text "沟通记录已添加"
    
    # 解决费用明细问题
    within "#fee_details" do
      click_link "解决问题", match: :first
    end
    
    fill_in "resolution", with: "问题已解决"
    click_button "提交"
    
    assert_text "问题已解决"
    
    # 标记沟通工单已解决
    click_link "标记已解决"
    fill_in "resolution_summary", with: "所有问题已解决"
    click_button "提交"
    
    assert_text "工单已标记为已解决"
    
    # 关闭沟通工单
    click_link "关闭"
    assert_text "工单已关闭"
    
    # 返回审核工单
    visit admin_audit_work_orders_path
    click_link "查看", match: :first
    
    # 审核通过
    click_link "审核通过"
    fill_in "comment", with: "审核通过"
    click_button "确认通过"
    
    assert_text "审核已通过"
    
    # 完成审核工单
    click_link "完成"
    assert_text "工单已完成"
  end
end
```

## 5. 性能测试

性能测试用于确保系统在预期负载下能够正常运行。在SCI2工单系统中，我们将使用JMeter进行性能测试。

### 5.1 性能测试计划

1. **基准测试**：测试系统在无负载情况下的响应时间
2. **负载测试**：测试系统在预期用户数量下的响应时间
3. **压力测试**：测试系统在超出预期用户数量下的响应时间
4. **耐久测试**：测试系统在长时间运行下的稳定性

### 5.2 性能测试指标

1. **响应时间**：页面加载时间应在2秒以内
2. **吞吐量**：系统每秒能处理的请求数
3. **错误率**：系统在负载下的错误率应低于1%
4. **资源使用率**：CPU、内存、磁盘IO和网络IO的使用率

### 5.3 性能优化策略

1. **数据库优化**：
   - 添加适当的索引
   - 优化查询语句
   - 使用数据库连接池

2. **缓存策略**：
   - 使用页面缓存
   - 使用片段缓存
   - 使用查询缓存

3. **代码优化**：
   - 减少数据库查询次数
   - 优化N+1查询问题
   - 使用批量操作替代循环操作

## 6. 测试数据准备

为了支持测试，我们需要准备各种测试数据。

### 6.1 测试夹具

```ruby
# test/fixtures/reimbursements.yml
valid_reimbursement:
  invoice_number: "R20250101001"
  document_name: "测试报销单"
  applicant: "张三"
  applicant_id: "EMP001"
  company: "测试公司"
  department: "测试部门"
  amount: 1000.00
  receipt_status: "pending"
  reimbursement_status: "processing"
  is_electronic: false
  is_complete: false

electronic_reimbursement:
  invoice_number: "R20250101002"
  document_name: "电子发票报销单"
  applicant: "李四"
  applicant_id: "EMP002"
  company: "测试公司"
  department: "财务部"
  amount: 2000.00
  receipt_status: "pending"
  reimbursement_status: "processing"
  is_electronic: true
  is_complete: false
```

### 6.2 测试数据生成

```ruby
# lib/tasks/generate_test_data.rake
namespace :test_data do
  desc "Generate test data for development"
  task generate: :environment do
    # 创建报销单
    10.times do |i|
      Reimbursement.create!(
        invoice_number: "R#{Time.current.strftime('%Y%m%d')}#{sprintf('%03d', i+1)}",
        document_name: "测试报销单#{i+1}",
        applicant: "测试用户#{i+1}",
        applicant_id: "EMP#{sprintf('%03d', i+1)}",
        company: "测试公司",
        department: ["研发部", "财务部", "市场部", "人事部"].sample,
        amount: rand(100..10000).to_f,
        receipt_status: ["pending", "received"].sample,
        reimbursement_status: ["pending", "processing", "closed"].sample,
        is_electronic: [true, false].sample,
        is_complete: false
      )
    end
    
    # 创建快递收单工单
    Reimbursement.where(is_electronic: false).each do |reimbursement|
      express_receipt = ExpressReceipt.create!(
        document_number: reimbursement.invoice_number,
        tracking_number: "SF#{rand(10**10)}",
        receive_date: Time.current - rand(1..10).days,
        receiver: "测试接收人",
        courier_company: ["顺丰", "圆通", "中通", "申通", "韵达"].sample
      )
      
      ExpressReceiptWorkOrder.create!(
        reimbursement: reimbursement,
        status: ["received", "processed", "completed"].sample,
        tracking_number: express_receipt.tracking_number,
        received_at: express_receipt.receive_date,
        courier_name: express_receipt.courier_company,
        created_by: 1
      )
      
      reimbursement.update(receipt_status: "received", receipt_date: express_receipt.receive_date)
    end
    
    # 创建审核工单
    Reimbursement.all.each do |reimbursement|
      AuditWorkOrder.create!(
        reimbursement: reimbursement,
        express_receipt_work_order: reimbursement.express_receipt_work_orders.first,
        status: ["pending", "processing", "auditing", "approved", "rejected", "needs_communication", "completed"].sample,
        created_by: 1
      )
    end
    
    # 创建费用明细
    Reimbursement.all.each do |reimbursement|
      rand(1..5).times do
        FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: ["交通费", "餐饮费", "住宿费", "办公用品", "其他"].sample,
          amount: rand(10..1000).to_f,
          currency: "CNY",
          fee_date: Time.current - rand(1..30).days,
          verification_status: ["pending", "verified", "problematic", "rejected"].sample
        )
      end
    end
    
    # 关联费用明细到审核工单
    AuditWorkOrder.all.each do |audit_work_order|
      audit_work_order.reimbursement.fee_details.each do |fee_detail|
        audit_work_order.select_fee_detail(fee_detail)
      end
    end
    
    puts "测试数据生成完成"
  end
end
```

## 7. 测试覆盖率目标

为了确保代码质量，我们设定以下测试覆盖率目标：

1. **模型**：90%以上的代码覆盖率
2. **服务**：85%以上的代码覆盖率
3. **控制器**：80%以上的代码覆盖率
4. **整体**：85%以上的代码覆盖率

我们将使用SimpleCov来监控测试覆盖率，并在CI/CD流程中集成覆盖率检查。

## 8. 持续集成与部署

为了确保代码质量和功能正确性，我们将在CI/CD流程中集成测试：

1. **提交前测试**：开发人员在提交代码前应运行单元测试
2. **CI测试**：在CI服务器上自动运行单元测试和集成测试
3. **部署前测试**：在部署到生产环境前运行完整的测试套件
4. **部署后测试**：在部署到生产环境后运行冒烟测试

## 9. 总结

通过实施这一全面的测试策略，我们可以确保SCI2工单系统的质量和功能正确性。测试将贯穿整个开发过程，从单元测试到集成测试再到系统测试，确保系统的各个组件和整体功能都能正常工作。
### 3.1 工单流程测试

```ruby
# test/integration/work_order_processing_test.rb
require 'test_helper'

class WorkOrderProcessingTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = admin_users(:admin)
    sign_in @admin_user
    
    @reimbursement = reimbursements(:valid_reimbursement)
  end
  
  test "complete express receipt work order flow" do
    # 创建快递收单工单
    express_receipt = ExpressReceipt.create!(
      document_number: @reimbursement.invoice_number,
      tracking_number: "SF1234567890",
      receive_date: Time.current,
      receiver: @admin_user.email,
      courier_company: "顺丰"
    )
    
    work_order = ExpressReceiptWorkOrder.create!(
      reimbursement: @reimbursement,
      status: "received",
      tracking_number: express_receipt.tracking_number,
      received_at: express_receipt.receive_date,
      courier_name: express_receipt.courier_company,
      created_by: @admin_user.id
    )
    
    # 处理工单
    put process_admin_express_receipt_work_order_path(work_order)
    assert_redirected_to admin_express_receipt_work_order_path(work_order)
    assert_equal "processed", work_order.reload.status
    
    # 完成工单
    put complete_admin_express_receipt_work_order_path(work_order)
    assert_redirected_to admin_express_receipt_work_order_path(work_order)
    assert_equal "completed", work_order.reload.status
    
    # 验证是否创建了审核工单
    audit_work_order = AuditWorkOrder.find_by(express_receipt_work_order_id: work_order.id)
    assert_not_nil audit_work_order
    assert_equal "pending", audit_work_order.status
  end