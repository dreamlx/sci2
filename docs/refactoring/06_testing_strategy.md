# SCI2 工单系统测试策略

## 1. 测试概述

测试是确保系统质量和功能正确性的关键环节。在SCI2工单系统的重构过程中，我们将采用多层次的测试策略，包括单元测试、集成测试和系统测试，以确保系统的各个组件和整体功能都能正常工作。

### 1.1 测试目标

1.  **验证功能正确性**：确保系统的各个功能按照预期工作
2.  **保证数据一致性**：确保数据在各个处理环节中保持一致
3.  **验证业务流程**：确保工单处理流程符合业务需求，包括更新的状态流转
4.  **测试边界条件**：确保系统在各种边界条件下能够正常工作
5.  **性能测试**：确保系统在预期负载下能够正常运行

### 1.2 测试环境

1.  **开发环境**：用于开发人员进行单元测试和基本功能测试
2.  **测试环境**：用于QA团队进行集成测试和系统测试
3.  **预生产环境**：用于进行最终的验收测试和性能测试

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
    assert @work_order.process!
    assert_equal "processed", @work_order.reload.status
  end

  test "should complete" do
    @work_order.status = "processed"
    assert @work_order.complete!
    assert_equal "completed", @work_order.reload.status
  end

  test "should create audit work order after complete" do
    @work_order.status = "processed"
    assert_difference 'AuditWorkOrder.count' do
      @work_order.complete!
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
    @auditing_work_order = audit_work_orders(:auditing) # Assuming fixture exists
    @needs_comm_work_order = audit_work_orders(:needs_communication) # Assuming fixture exists
  end

  test "should be valid" do
    assert @work_order.valid?
  end

  test "should start processing" do
    assert @work_order.start_processing!
    assert_equal "processing", @work_order.reload.status
  end

  test "should start audit" do
    @work_order.status = "processing" # Set state manually for test setup
    assert @work_order.start_audit!
    assert_equal "auditing", @work_order.reload.status
  end

  test "should approve from auditing" do
    assert @auditing_work_order.approve!
    assert_equal "approved", @auditing_work_order.reload.status
    assert_equal "approved", @auditing_work_order.audit_result
    assert_not_nil @auditing_work_order.audit_date
  end

  test "should reject from auditing" do
    assert @auditing_work_order.reject!
    assert_equal "rejected", @auditing_work_order.reload.status
    assert_equal "rejected", @auditing_work_order.audit_result
    assert_not_nil @auditing_work_order.audit_date
  end

  test "should reject from needs_communication" do
    assert @needs_comm_work_order.reject!
    assert_equal "rejected", @needs_comm_work_order.reload.status
    assert_equal "rejected", @needs_comm_work_order.audit_result
    assert_not_nil @needs_comm_work_order.audit_date
  end

  test "should need communication" do
    assert @auditing_work_order.need_communication!
    assert_equal "needs_communication", @auditing_work_order.reload.status
  end

  test "should resume audit" do
    assert @needs_comm_work_order.resume_audit!
    assert_equal "auditing", @needs_comm_work_order.reload.status
  end

  test "should complete from approved" do
    @work_order.status = "approved" # Set state manually
    assert @work_order.complete!
    assert_equal "completed", @work_order.reload.status
  end

   test "should complete from rejected" do
    @work_order.status = "rejected" # Set state manually
    assert @work_order.complete!
    assert_equal "completed", @work_order.reload.status
  end

  test "should create communication work order" do
    assert_difference 'CommunicationWorkOrder.count' do
      @auditing_work_order.create_communication_work_order(
        communication_method: "email",
        initiator_role: "auditor"
      )
    end

    assert_equal "needs_communication", @auditing_work_order.reload.status # Reload to check status change

    comm_order = CommunicationWorkOrder.last
    assert_equal @auditing_work_order.reimbursement_id, comm_order.reimbursement_id
    assert_equal @auditing_work_order.id, comm_order.audit_work_order_id
    assert_equal "open", comm_order.status
  end
end
```

#### 2.2.3 沟通工单测试

```ruby
# test/models/communication_work_order_test.rb
require 'test_helper'

class CommunicationWorkOrderTest < ActiveSupport::TestCase
  setup do
    @work_order = communication_work_orders(:open)
    @audit_work_order = @work_order.audit_work_order
  end

  test "should be valid" do
    assert @work_order.valid?
  end

  test "should start communication" do
    assert @work_order.start_communication!
    assert_equal "in_progress", @work_order.reload.status
  end

  test "should resolve" do
    @work_order.status = "in_progress" # Set state manually
    assert @work_order.resolve!
    assert_equal "resolved", @work_order.reload.status
  end

  test "should mark unresolved" do
    @work_order.status = "in_progress" # Set state manually
    assert @work_order.mark_unresolved!
    assert_equal "unresolved", @work_order.reload.status
  end

  test "should close from resolved" do
    @work_order.status = "resolved" # Set state manually
    assert @work_order.close!
    assert_equal "closed", @work_order.reload.status
  end

  test "should close from unresolved" do
    @work_order.status = "unresolved" # Set state manually
    assert @work_order.close!
    assert_equal "closed", @work_order.reload.status
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
    @audit_work_order.update(status: "needs_communication") # Ensure parent is waiting
    @work_order.status = "in_progress" # Set state manually

    @work_order.resolve!

    assert_equal "auditing", @audit_work_order.reload.status
  end

  test "should notify parent work order after mark unresolved" do
    @audit_work_order.update(status: "needs_communication") # Ensure parent is waiting
    @work_order.status = "in_progress" # Set state manually

    @work_order.mark_unresolved!

    assert_equal "auditing", @audit_work_order.reload.status
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
    @admin_user = admin_users(:admin) # Assuming fixture exists
    @file = fixture_file_upload('files/test_reimbursements.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') # Adjust path if needed
  end

  test "should import reimbursements" do
    service = ReimbursementImportService.new(@file, @admin_user)
    result = service.import

    assert result[:success]
    # Adjust counts based on your fixture file
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
    # Ensure fixture file has at least one non-electronic entry
    assert_difference 'AuditWorkOrder.count', 1 do # Adjust count based on fixture
      service = ReimbursementImportService.new(@file, @admin_user)
      service.import
    end
    # Assuming the xlsx fixture has the same data as the csv fixture
  end

  # Add tests for other import services (ExpressReceipt, FeeDetail, OperationHistory)
  # including tests for handling missing reimbursements
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
    @auditing_work_order = audit_work_orders(:auditing)
    @needs_comm_work_order = audit_work_orders(:needs_communication)
    @service = AuditWorkOrderService.new(@work_order, @admin_user)
    @auditing_service = AuditWorkOrderService.new(@auditing_work_order, @admin_user)
    @needs_comm_service = AuditWorkOrderService.new(@needs_comm_work_order, @admin_user)
  end

  test "should start processing" do
    assert @service.start_processing!
    assert_equal "processing", @work_order.reload.status
  end

   test "should start audit" do
    @work_order.update(status: 'processing') # Setup state
    assert @service.start_audit!
    assert_equal "auditing", @work_order.reload.status
  end

  test "should approve from auditing with comment" do
    assert @auditing_service.approve!("审核通过")
    assert_equal "approved", @auditing_work_order.reload.status
    assert_equal "approved", @auditing_work_order.audit_result
    assert_equal "审核通过", @auditing_work_order.audit_comment
  end

  test "should update fee details after approve" do
    # Setup: Create and associate a fee detail
    fee_detail = fee_details(:pending) # Assuming fixture exists
    @auditing_work_order.select_fee_detail(fee_detail)
    fee_detail.update!(verification_status: 'pending') # Ensure starting state

    @auditing_service.approve!

    assert_equal "verified", fee_detail.reload.verification_status
  end

  test "should reject from auditing with comment" do
     assert @auditing_service.reject!("审核拒绝")
     assert_equal "rejected", @auditing_work_order.reload.status
     assert_equal "rejected", @auditing_work_order.audit_result
     assert_equal "审核拒绝", @auditing_work_order.audit_comment
  end

   test "should reject from needs_communication with comment" do
     assert @needs_comm_service.reject!("沟通后拒绝")
     assert_equal "rejected", @needs_comm_work_order.reload.status
     assert_equal "rejected", @needs_comm_work_order.audit_result
     assert_equal "沟通后拒绝", @needs_comm_work_order.audit_comment
  end

  test "should update fee details after reject" do
    # Setup: Create and associate a fee detail
    fee_detail = fee_details(:pending)
    @auditing_work_order.select_fee_detail(fee_detail)
    fee_detail.update!(verification_status: 'pending') # Ensure starting state

    @auditing_service.reject!

    assert_equal "rejected", fee_detail.reload.verification_status
  end

  test "should need communication" do
    assert @auditing_service.need_communication!
    assert_equal "needs_communication", @auditing_work_order.reload.status
  end

  test "should resume audit" do
    assert @needs_comm_service.resume_audit!
    assert_equal "auditing", @needs_comm_work_order.reload.status
  end

  test "should create communication work order" do
    assert_difference 'CommunicationWorkOrder.count' do
      @auditing_service.create_communication_work_order!(
        communication_method: "email",
        initiator_role: "auditor",
        content: "需要沟通"
      )
    end

    assert_equal "needs_communication", @auditing_work_order.reload.status

    comm_order = CommunicationWorkOrder.last
    assert_equal 1, comm_order.communication_records.count
    assert_equal "需要沟通", comm_order.communication_records.first.content
  end

  # Add test for verify_fee_detail using FeeDetailVerificationService
  test "should verify fee detail via verification service" do
    fee_detail = fee_details(:pending)
    @auditing_work_order.select_fee_detail(fee_detail)
    fee_detail.update!(verification_status: 'pending')

    mock_verification_service = Minitest::Mock.new
    mock_verification_service.expect(:update_verification_status!, true, [fee_detail, 'verified', '测试备注'])

    FeeDetailVerificationService.stub :new, mock_verification_service do
      result = @auditing_service.verify_fee_detail!(fee_detail.id, 'verified', '测试备注')
      assert result
    end
    mock_verification_service.verify
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
    assert @service.start_communication!
    assert_equal "in_progress", @work_order.reload.status
  end

  test "should resolve with summary" do
    @work_order.update(status: "in_progress") # Setup state

    assert @service.resolve!("问题已解决")
    assert_equal "resolved", @work_order.reload.status
    assert_equal "问题已解决", @work_order.resolution_summary
  end

   test "should mark unresolved with summary" do
    @work_order.update(status: "in_progress") # Setup state

    assert @service.mark_unresolved!("无法解决")
    assert_equal "unresolved", @work_order.reload.status
    assert_equal "无法解决", @work_order.resolution_summary
  end

  test "should close from resolved" do
     @work_order.update(status: "resolved") # Setup state
     assert @service.close!
     assert_equal "closed", @work_order.reload.status
  end

   test "should close from unresolved" do
     @work_order.update(status: "unresolved") # Setup state
     assert @service.close!
     assert_equal "closed", @work_order.reload.status
  end

  test "should add communication record" do
    assert_difference 'CommunicationRecord.count' do
      @service.add_communication_record!(
        content: "测试沟通内容",
        communicator_role: "auditor",
        communication_method: "email"
        # communicator_name is handled by service
      )
    end

    record = CommunicationRecord.last
    assert_equal @work_order.id, record.communication_work_order_id
    assert_equal "测试沟通内容", record.content
    assert_equal "auditor", record.communicator_role
    assert_equal @admin_user.email, record.communicator_name
  end

  test "should resolve fee detail issue (update comment only)" do
     fee_detail = fee_details(:problematic) # Assuming fixture exists
     selection = @work_order.fee_detail_selections.create!(fee_detail: fee_detail, verification_status: 'problematic')

     assert @service.resolve_fee_detail_issue!(fee_detail.id, "已确认，无问题")
     assert_equal "已确认，无问题", selection.reload.verification_comment
     assert_equal "problematic", fee_detail.reload.verification_status # Global status unchanged
  end
end
```

## 3. 集成测试

集成测试用于测试多个组件之间的交互，确保它们能够协同工作。在SCI2工单系统中，我们将重点测试工单流程和数据导入流程。

### 3.1 工单流程测试

```ruby
# test/integration/work_order_processing_test.rb
require 'test_helper'

class WorkOrderProcessingTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = admin_users(:admin)
    sign_in @admin_user # Assuming Devise or similar authentication

    @reimbursement = reimbursements(:valid_reimbursement) # Assuming fixture exists
  end

  test "complete express receipt work order flow" do
    # Setup: Create ExpressReceiptWorkOrder (or use fixture)
    work_order = express_receipt_work_orders(:received)
    work_order.update!(reimbursement: @reimbursement)

    # Process
    put process_admin_express_receipt_work_order_path(work_order) # Assuming this action calls the service which uses the bang method
    assert_redirected_to admin_express_receipt_work_order_path(work_order)
    assert_equal "processed", work_order.reload.status

    # Complete
    put complete_admin_express_receipt_work_order_path(work_order) # Assuming this action calls the service which uses the bang method
    assert_redirected_to admin_express_receipt_work_order_path(work_order)
    assert_equal "completed", work_order.reload.status

    # Verify AuditWorkOrder creation
    audit_work_order = AuditWorkOrder.find_by(express_receipt_work_order_id: work_order.id)
    assert_not_nil audit_work_order
    assert_equal "pending", audit_work_order.status
  end

  test "complete audit work order flow - approve path" do
    # Setup: Create AuditWorkOrder (or use fixture)
    audit_work_order = audit_work_orders(:pending)
    audit_work_order.update!(reimbursement: @reimbursement)
    fee_detail = fee_details(:pending)
    audit_work_order.select_fee_detail(fee_detail)

    # Start Processing
    put start_processing_admin_audit_work_order_path(audit_work_order) # Assuming this action calls the service which uses the bang method
    assert_redirected_to admin_audit_work_order_path(audit_work_order)
    assert_equal "processing", audit_work_order.reload.status

    # Start Audit
    put start_audit_admin_audit_work_order_path(audit_work_order) # Assuming this action calls the service which uses the bang method
    assert_redirected_to admin_audit_work_order_path(audit_work_order)
    assert_equal "auditing", audit_work_order.reload.status

    # Approve
    post do_approve_admin_audit_work_order_path(audit_work_order), params: { comment: "审核通过" } # Assuming this action calls the service which uses the bang method
    assert_redirected_to admin_audit_work_order_path(audit_work_order)
    assert_equal "approved", audit_work_order.reload.status
    assert_equal "approved", audit_work_order.audit_result

    # Complete
    put complete_admin_audit_work_order_path(audit_work_order) # Assuming this action calls the service which uses the bang method
    assert_redirected_to admin_audit_work_order_path(audit_work_order)
    assert_equal "completed", audit_work_order.reload.status

    # Verify Fee Detail Status
    assert_equal "verified", fee_detail.reload.verification_status
  end

   test "complete audit work order flow - reject from needs_communication path" do
    # Setup: Create AuditWorkOrder in needs_communication state
    audit_work_order = audit_work_orders(:needs_communication)
    audit_work_order.update!(reimbursement: @reimbursement)
    fee_detail = fee_details(:problematic)
    audit_work_order.select_fee_detail(fee_detail)

    # Reject directly
    post do_reject_admin_audit_work_order_path(audit_work_order), params: { comment: "沟通后拒绝" } # Assuming this action calls the service which uses the bang method
    assert_redirected_to admin_audit_work_order_path(audit_work_order)
    assert_equal "rejected", audit_work_order.reload.status
    assert_equal "rejected", audit_work_order.audit_result

    # Complete
    put complete_admin_audit_work_order_path(audit_work_order) # Assuming this action calls the service which uses the bang method
    assert_redirected_to admin_audit_work_order_path(audit_work_order)
    assert_equal "completed", audit_work_order.reload.status

    # Verify Fee Detail Status
    assert_equal "rejected", fee_detail.reload.verification_status
  end


  test "communication work order flow" do
    # Setup: Create AuditWorkOrder in auditing state
    audit_work_order = audit_work_orders(:auditing)
    audit_work_order.update!(reimbursement: @reimbursement)

    # Create Communication Work Order
    post create_communication_admin_audit_work_order_path(audit_work_order), params: {
      communication_method: "email",
      initiator_role: "auditor",
      content: "需要沟通"
      # Optionally add fee_detail_ids: [fee_detail.id]
    }

    communication_work_order = CommunicationWorkOrder.last
    assert_redirected_to admin_communication_work_order_path(communication_work_order)
    assert_equal "open", communication_work_order.status
    assert_equal "needs_communication", audit_work_order.reload.status

    # Start Communication
    put start_communication_admin_communication_work_order_path(communication_work_order) # Assuming this action calls the service which uses the bang method
    assert_redirected_to admin_communication_work_order_path(communication_work_order)
    assert_equal "in_progress", communication_work_order.reload.status

    # Add Communication Record
    post create_communication_record_admin_communication_work_order_path(communication_work_order), params: {
      communication_record: { # Assuming form uses nested params
        content: "已沟通",
        communicator_role: "auditor",
        communication_method: "email"
      }
    }
    assert_redirected_to admin_communication_work_order_path(communication_work_order)
    assert_equal 1, communication_work_order.communication_records.count # Check count based on setup

    # Mark Resolved
    post do_resolve_admin_communication_work_order_path(communication_work_order), params: { # Assuming this action calls the service which uses the bang method
      resolution_summary: "问题已解决"
    }
    assert_redirected_to admin_communication_work_order_path(communication_work_order)
    assert_equal "resolved", communication_work_order.reload.status
    assert_equal "auditing", audit_work_order.reload.status # Parent notified

    # Close Communication Work Order
    put close_admin_communication_work_order_path(communication_work_order) # Assuming this action calls the service which uses the bang method
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
    file = fixture_file_upload('files/test_reimbursements.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

    assert_difference 'Reimbursement.count', 2 do # Adjust based on fixture
      post import_admin_reimbursements_path, params: { file: file }
    end

    assert_redirected_to admin_reimbursements_path
    # Add assertions for flash messages if needed
  end

  test "import express receipts requires existing reimbursement" do
     # Attempt to import receipts without importing reimbursements first
     receipt_file = fixture_file_upload('files/test_express_receipts.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
     assert_no_difference ['ExpressReceipt.count', 'ExpressReceiptWorkOrder.count'] do
        post import_admin_express_receipts_path, params: { file: receipt_file }
     end
     # Assert flash message indicates missing reimbursements or check service result
     assert_match /报销单不存在/, flash[:alert] # Or check response body/service result structure
  end

  test "import express receipts successfully after reimbursement import" do
    # 1. Import Reimbursements
    reimbursement_file = fixture_file_upload('files/test_reimbursements.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    post import_admin_reimbursements_path, params: { file: reimbursement_file }
    assert_response :redirect

    # 2. Import Express Receipts
    receipt_file = fixture_file_upload('files/test_express_receipts.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    assert_difference 'ExpressReceipt.count', 2 do # Adjust based on fixture
      assert_difference 'ExpressReceiptWorkOrder.count', 2 do # Adjust based on fixture
        post import_admin_express_receipts_path, params: { file: receipt_file }
      end
    end
    assert_redirected_to admin_express_receipts_path # Assuming ActiveAdmin resource path

    # Verify reimbursement status update
    reimbursement = Reimbursement.find_by(invoice_number: "R20250101001") # Use actual number from fixture
    assert_equal "received", reimbursement.receipt_status
    assert_not_nil reimbursement.receipt_date
  end

  # Add similar tests for FeeDetail and OperationHistory imports,
  # testing both failure without prior reimbursement import and success after.

  test "import fee details successfully after reimbursement import" do
    # 1. Import Reimbursements
    reimbursement_file = fixture_file_upload('files/test_reimbursements.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    post import_admin_reimbursements_path, params: { file: reimbursement_file }
    reimbursement = Reimbursement.find_by(invoice_number: "R20250101001") # Use actual number
    # Create an audit work order manually if needed for association test
    audit_work_order = AuditWorkOrder.create!(reimbursement: reimbursement, status: 'pending', created_by: @admin_user.id)


    # 2. Import Fee Details
    fee_detail_file = fixture_file_upload('files/test_fee_details.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    assert_difference 'FeeDetail.count', 3 do # Adjust based on fixture
      assert_difference 'FeeDetailSelection.count', 3 do # Adjust based on fixture
         post import_admin_fee_details_path, params: { file: fee_detail_file }
      end
    end
    assert_redirected_to admin_fee_details_path # Assuming ActiveAdmin resource path

    # Verify association
    assert_equal 3, audit_work_order.reload.fee_details.count
    assert_equal 'pending', FeeDetail.last.verification_status
  end

  test "import operation histories successfully after reimbursement import" do
     # 1. Import Reimbursements
    reimbursement_file = fixture_file_upload('files/test_reimbursements.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    post import_admin_reimbursements_path, params: { file: reimbursement_file }
    reimbursement = Reimbursement.find_by(invoice_number: "R20250101001") # Use actual number

    # 2. Import Operation History
    history_file = fixture_file_upload('files/test_operation_histories.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    assert_difference 'OperationHistory.count', 2 do # Adjust based on fixture
       post import_admin_operation_histories_path, params: { file: history_file }
    end
     assert_redirected_to admin_operation_histories_path # Assuming ActiveAdmin resource path

    # Verify reimbursement status update based on history
    assert reimbursement.reload.is_complete
    assert_equal "closed", reimbursement.reimbursement_status
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
    @audit_work_order = audit_work_orders(:auditing) # Assume fixture in auditing state
    @audit_work_order.update!(reimbursement: @reimbursement)

    @fee_detail = fee_details(:pending) # Assume fixture exists
    @fee_detail.update!(document_number: @reimbursement.invoice_number, verification_status: 'pending')

    @audit_work_order.select_fee_detail(@fee_detail)
    @selection = @audit_work_order.fee_detail_selections.find_by(fee_detail: @fee_detail)
  end

  test "verify fee detail manually in audit work order" do
    # Simulate going to the verify form and submitting
    post do_verify_fee_detail_admin_audit_work_order_path(@audit_work_order), params: {
      fee_detail_id: @fee_detail.id,
      verification_status: "verified",
      comment: "手动验证通过"
    }

    assert_redirected_to admin_audit_work_order_path(@audit_work_order)
    assert_equal "verified", @fee_detail.reload.verification_status
    assert_equal "verified", @selection.reload.verification_status
    assert_equal "手动验证通过", @selection.verification_comment
  end

  test "mark fee detail as problematic and create communication" do
     # Simulate clicking 'Mark Problematic' which leads to 'New Communication' form
     post create_communication_admin_audit_work_order_path(@audit_work_order), params: {
       communication_method: "system",
       initiator_role: "auditor",
       content: "金额有问题",
       fee_detail_ids: [@fee_detail.id] # Pass the fee detail ID
     }

     communication_work_order = CommunicationWorkOrder.last
     assert_redirected_to admin_communication_work_order_path(communication_work_order)

     # Verify fee detail and selection status
     assert_equal "problematic", @fee_detail.reload.verification_status
     assert_equal "problematic", @selection.reload.verification_status

     # Verify communication work order creation and association
     assert_not_nil communication_work_order
     assert_equal @audit_work_order.id, communication_work_order.audit_work_order_id
     assert_equal 1, communication_work_order.fee_detail_selections.count
     assert_equal @fee_detail.id, communication_work_order.fee_details.first.id
     assert_equal "needs_communication", @audit_work_order.reload.status
  end

  test "fee detail status remains problematic after communication resolved" do
    # 1. Mark as problematic and create communication WO
    post create_communication_admin_audit_work_order_path(@audit_work_order), params: {
       communication_method: "system", initiator_role: "auditor", content: "金额有问题", fee_detail_ids: [@fee_detail.id]
    }
    communication_work_order = CommunicationWorkOrder.last
    assert_equal "problematic", @fee_detail.reload.verification_status

    # 2. Resolve communication WO
    post do_resolve_admin_communication_work_order_path(communication_work_order), params: { resolution_summary: "已沟通确认" }
    assert_equal "resolved", communication_work_order.reload.status
    assert_equal "auditing", @audit_work_order.reload.status # Audit WO resumes

    # 3. Verify fee detail status is STILL problematic
    assert_equal "problematic", @fee_detail.reload.verification_status
    assert_equal "problematic", @selection.reload.verification_status # Selection status also remains

    # 4. Manually verify the fee detail in the audit work order
    post do_verify_fee_detail_admin_audit_work_order_path(@audit_work_order), params: {
      fee_detail_id: @fee_detail.id,
      verification_status: "verified",
      comment: "沟通后确认无误"
    }
    assert_redirected_to admin_audit_work_order_path(@audit_work_order)
    assert_equal "verified", @fee_detail.reload.verification_status
    assert_equal "verified", @selection.reload.verification_status
  end

  test "cannot update fee detail status if reimbursement is closed" do
     @reimbursement.update!(is_complete: true) # Close the reimbursement

     post do_verify_fee_detail_admin_audit_work_order_path(@audit_work_order), params: {
      fee_detail_id: @fee_detail.id,
      verification_status: "verified",
      comment: "尝试更新"
    }

    # Assert redirection back or specific error message, and status unchanged
    assert_response :success # Should re-render the form with an error
    assert_select ".inline-errors", /关联报销单已关闭/ # Check for specific error text
    assert_equal "pending", @fee_detail.reload.verification_status # Status should not change
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
    login_as(@admin_user, scope: :admin_user) # Use appropriate login helper

    # It's often better to create test data programmatically than rely solely on fixtures for system tests
    @reimbursement = Reimbursement.create!( # Create necessary data
      invoice_number: "SYS-TEST-001",
      document_name: "System Test Reimbursement",
      applicant: "System Tester", applicant_id: "SYS001",
      company: "Test Co", department: "Test Dept", amount: 500,
      is_electronic: false, is_complete: false, receipt_status: 'pending', reimbursement_status: 'pending'
    )
    @fee_detail1 = FeeDetail.create!(document_number: @reimbursement.invoice_number, fee_type: "交通", amount: 100, verification_status: 'pending')
    @fee_detail2 = FeeDetail.create!(document_number: @reimbursement.invoice_number, fee_type: "餐饮", amount: 50, verification_status: 'pending')

    # Assume import creates necessary work orders, or create them manually for the test
    @express_wo = ExpressReceiptWorkOrder.create!(reimbursement: @reimbursement, status: 'received', tracking_number: 'SF-SYS-123', created_by: @admin_user.id)

  end

  test "complete workflow from express receipt to audit completion with communication" do
    # 1. Process Express Receipt WO
    visit admin_express_receipt_work_order_path(@express_wo)
    click_link "处理"
    assert_text "工单已处理"
    assert_equal "processed", @express_wo.reload.status

    # 2. Complete Express Receipt WO (triggers Audit WO creation)
    click_link "完成"
    assert_text "工单已完成"
    assert_equal "completed", @express_wo.reload.status
    audit_wo = AuditWorkOrder.find_by!(express_receipt_work_order_id: @express_wo.id)
    assert_equal "pending", audit_wo.status
    # Verify fee details were associated
    assert_equal 2, audit_wo.fee_details.count

    # 3. Process Audit WO
    visit admin_audit_work_order_path(audit_wo)
    click_link "开始处理"
    assert_text "工单已开始处理"
    assert_equal "processing", audit_wo.reload.status

    click_link "开始审核"
    assert_text "工单已开始审核"
    assert_equal "auditing", audit_wo.reload.status

    # 4. Verify one Fee Detail
    within "#fee_details" do # Assuming the panel has id="fee_details" or similar selector
      # Find the row for fee_detail1
      find("tr", text: @fee_detail1.fee_type).click_link("更新验证状态")
    end
    # Now on the verify_fee_detail page
    select "已验证", from: "audit_work_order_verification_status" # Adjust field name if needed
    fill_in "audit_work_order_comment", with: "验证通过" # Adjust field name if needed
    click_button "提交"
    assert_text "费用明细 ##{@fee_detail1.id} 状态已更新"
    assert_equal "verified", @fee_detail1.reload.verification_status

    # 5. Mark another Fee Detail as problematic (Create Communication)
    visit admin_audit_work_order_path(audit_wo) # Go back to audit WO
    within "#fee_details" do
       # Find the row for fee_detail2
      find("tr", text: @fee_detail2.fee_type).click_link("创建沟通工单") # Link text updated in AA integration
    end
    # Now on the new_communication page
    select "email", from: "communication_method"
    select "auditor", from: "initiator_role"
    fill_in "content", with: "餐饮费金额疑问"
    check "fee_detail_ids_#{@fee_detail2.id}" # Check the box for the specific fee detail
    click_button "创建沟通工单"
    assert_text "沟通工单已创建"
    communication_wo = CommunicationWorkOrder.last
    assert_equal audit_wo.id, communication_wo.audit_work_order_id
    assert_equal "problematic", @fee_detail2.reload.verification_status
    assert_equal "needs_communication", audit_wo.reload.status

    # 6. Process Communication WO
    visit admin_communication_work_order_path(communication_wo)
    click_link "开始沟通"
    assert_text "工单已开始沟通"

    click_link "添加沟通记录"
    fill_in "communication_record_content", with: "已与申请人沟通确认" # Adjust field name
    select "审核人", from: "communication_record_communicator_role" # Adjust field name
    select "邮件", from: "communication_record_communication_method" # Adjust field name
    click_button "添加记录"
    assert_text "沟通记录已添加"

    # Mark Communication WO Resolved
    click_link "标记已解决"
    fill_in "resolution_summary", with: "金额无误"
    click_button "确认已解决"
    assert_text "工单已标记为已解决"
    assert_equal "resolved", communication_wo.reload.status
    assert_equal "auditing", audit_wo.reload.status # Should resume audit

    # Close Communication WO
    click_link "关闭"
    accept_alert # If using confirm dialog
    assert_text "工单已关闭"
    assert_equal "closed", communication_wo.reload.status

    # 7. Manually update the problematic Fee Detail in Audit WO
    visit admin_audit_work_order_path(audit_wo)
    assert_equal "problematic", @fee_detail2.reload.verification_status # Verify it's still problematic
    within "#fee_details" do
       find("tr", text: @fee_detail2.fee_type).click_link("更新验证状态")
    end
    select "已验证", from: "audit_work_order_verification_status" # Adjust field name
    fill_in "audit_work_order_comment", with: "沟通后确认无误" # Adjust field name
    click_button "提交"
    assert_text "费用明细 ##{@fee_detail2.id} 状态已更新"
    assert_equal "verified", @fee_detail2.reload.verification_status

    # 8. Approve Audit WO
    visit admin_audit_work_order_path(audit_wo)
    click_link "审核通过"
    fill_in "comment", with: "全部审核通过"
    click_button "确认通过"
    assert_text "审核已通过"
    assert_equal "approved", audit_wo.reload.status

    # 9. Complete Audit WO
    click_link "完成"
    accept_alert # If using confirm dialog
    assert_text "工单已完成"
    assert_equal "completed", audit_wo.reload.status

    # Final check on fee details
    assert_equal "verified", @fee_detail1.reload.verification_status
    assert_equal "verified", @fee_detail2.reload.verification_status
  end
end
```

## 5. 性能测试

性能测试用于确保系统在预期负载下能够正常运行。在SCI2工单系统中，我们将使用JMeter进行性能测试。

### 5.1 性能测试计划

1.  **基准测试**：测试系统在无负载情况下的响应时间
2.  **负载测试**：测试系统在预期用户数量下的响应时间
3.  **压力测试**：测试系统在超出预期用户数量下的响应时间
4.  **耐久测试**：测试系统在长时间运行下的稳定性

### 5.2 性能测试指标

1.  **响应时间**：页面加载时间应在2秒以内
2.  **吞吐量**：系统每秒能处理的请求数
3.  **错误率**：系统在负载下的错误率应低于1%
4.  **资源使用率**：CPU、内存、磁盘IO和网络IO的使用率

### 5.3 性能优化策略

1.  **数据库优化**：
    *   添加适当的索引
    *   优化查询语句
    *   使用数据库连接池
2.  **缓存策略**：
    *   使用页面缓存
    *   使用片段缓存
    *   使用查询缓存
3.  **代码优化**：
    *   减少数据库查询次数
    *   优化N+1查询问题
    *   使用批量操作替代循环操作

## 6. 测试数据准备

为了支持测试，我们需要准备各种测试数据。

### 6.1 测试夹具

```yaml
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

# test/fixtures/express_receipt_work_orders.yml
received:
  reimbursement: valid_reimbursement
  status: received
  tracking_number: SF111222333
  received_at: <%= Time.current - 1.day %>
  courier_name: 顺丰
  created_by: 1 # Or reference admin_users fixture

# test/fixtures/audit_work_orders.yml
pending:
  reimbursement: valid_reimbursement
  status: pending
  created_by: 1

auditing:
  reimbursement: valid_reimbursement
  status: auditing
  created_by: 1

needs_communication:
   reimbursement: valid_reimbursement
   status: needs_communication
   created_by: 1

# test/fixtures/communication_work_orders.yml
open:
  reimbursement: valid_reimbursement
  audit_work_order: auditing # Link to an existing audit work order fixture
  status: open
  communication_method: email
  initiator_role: auditor
  created_by: 1

# test/fixtures/fee_details.yml
pending:
  reimbursement: valid_reimbursement
  document_number: <%= ActiveRecord::FixtureSet.identify(:valid_reimbursement).to_s %> # Use fixture ID if needed, or invoice number
  fee_type: 交通费
  amount: 150.0
  verification_status: pending

problematic:
   reimbursement: valid_reimbursement
   document_number: <%= ActiveRecord::FixtureSet.identify(:valid_reimbursement).to_s %>
   fee_type: 餐饮费
   amount: 85.5
   verification_status: problematic

# test/fixtures/admin_users.yml
admin:
  email: admin@example.com
  password: password
  password_confirmation: password

```

### 6.2 测试数据生成

```ruby
# lib/tasks/generate_test_data.rake
namespace :test_data do
  desc "Generate test data for development"
  task generate: :environment do
    puts "Generating test data..."
    AdminUser.find_or_create_by!(email: 'dev_admin@example.com') do |user|
      user.password = 'password'
      user.password_confirmation = 'password'
    end
    admin_user = AdminUser.first

    # 创建报销单
    10.times do |i|
      Reimbursement.find_or_create_by!(invoice_number: "DEV#{Time.current.strftime('%Y%m%d')}#{sprintf('%03d', i+1)}") do |r|
        r.document_name = "开发测试报销单#{i+1}"
        r.applicant = "开发用户#{i+1}"
        r.applicant_id = "DEV#{sprintf('%03d', i+1)}"
        r.company = "开发公司"
        r.department = ["研发部", "财务部", "市场部", "人事部"].sample
        r.amount = rand(100..10000).to_f
        r.receipt_status = ["pending", "received"].sample
        r.reimbursement_status = ["pending", "processing", "closed"].sample
        r.is_electronic = [true, false].sample
        r.is_complete = (r.reimbursement_status == 'closed')
        r.receipt_date = (r.receipt_status == 'received' ? Time.current - rand(1..5).days : nil)
      end
    end

    # 创建快递收单工单 (为部分非电子、未收单的报销单创建)
    Reimbursement.where(is_electronic: false, receipt_status: 'pending').limit(5).each do |reimbursement|
       ExpressReceiptWorkOrder.find_or_create_by!(reimbursement: reimbursement) do |erwo|
         erwo.status = "received"
         erwo.tracking_number = "SF-DEV-#{rand(10**9)}"
         erwo.received_at = Time.current - rand(1..10).days
         erwo.courier_name = ["顺丰", "圆通", "中通"].sample
         erwo.created_by = admin_user.id
       end
       # 更新报销单状态
       reimbursement.update(receipt_status: 'received', receipt_date: Time.current - rand(1..10).days)
    end

    # 创建审核工单 (为部分非电子或快递收单完成的创建)
    Reimbursement.includes(:express_receipt_work_orders).where(is_electronic: false).or(Reimbursement.where(id: ExpressReceiptWorkOrder.where(status: 'completed').select(:reimbursement_id))).limit(8).each do |reimbursement|
       AuditWorkOrder.find_or_create_by!(reimbursement: reimbursement) do |awo|
          awo.express_receipt_work_order = reimbursement.express_receipt_work_orders.first # Link if exists
          awo.status = ["pending", "processing", "auditing", "needs_communication"].sample
          awo.created_by = admin_user.id
       end
    end

    # 创建费用明细并关联
    Reimbursement.all.each do |reimbursement|
      rand(1..5).times do
        fd = FeeDetail.create!(
          document_number: reimbursement.invoice_number,
          fee_type: ["交通费", "餐饮费", "住宿费", "办公用品", "其他"].sample,
          amount: rand(10..1000).to_f,
          currency: "CNY",
          fee_date: Time.current - rand(1..30).days,
          verification_status: ["pending", "verified", "problematic", "rejected"].sample
        )
        # 关联到第一个未完成的审核工单
        audit_wo = reimbursement.audit_work_orders.where.not(status: 'completed').first
        audit_wo&.select_fee_detail(fd)
      end
    end

    puts "Test data generation complete."
  end
end
```

## 7. 测试覆盖率目标

为了确保代码质量，我们设定以下测试覆盖率目标：

1.  **模型**：90%以上的代码覆盖率
2.  **服务**：85%以上的代码覆盖率
3.  **控制器/ActiveAdmin资源**：80%以上的代码覆盖率
4.  **整体**：85%以上的代码覆盖率

我们将使用SimpleCov来监控测试覆盖率，并在CI/CD流程中集成覆盖率检查。

## 8. 持续集成与部署

为了确保代码质量和功能正确性，我们将在CI/CD流程中集成测试：

1.  **提交前测试**：开发人员在提交代码前应运行单元测试
2.  **CI测试**：在CI服务器上自动运行单元测试和集成测试
3.  **部署前测试**：在部署到生产环境前运行完整的测试套件
4.  **部署后测试**：在部署到生产环境后运行冒烟测试

## 9. 总结

通过实施这一全面的测试策略，我们可以确保SCI2工单系统的质量和功能正确性。测试将贯穿整个开发过程，从单元测试到集成测试再到系统测试，确保系统的各个组件和整体功能都能正常工作。