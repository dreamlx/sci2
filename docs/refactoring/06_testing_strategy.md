# SCI2 工单系统测试策略 (STI 版本 - v2)

## 1. 测试概述

本测试策略旨在确保基于单表继承 (STI) 模型重构的 SCI2 工单系统符合最新的业务需求 (`需求讨论记录`) 和测试计划 (`docs/1-2SCI2工单系统测试计划_v3.md`)。数据库结构基于 "Drop and Rebuild" 策略和导入文件 (`docs/3.数据导入格式参考.md`) 设计。我们将采用单元测试、集成测试和系统测试相结合的方式。

### 1.1 测试目标

1.  **验证功能正确性**: 确保 STI 模型下的工单创建、状态流转、关联关系、表单字段处理 (包括共享字段) 符合预期。
2.  **保证数据一致性**: 确保数据在导入、处理、状态变更过程中保持一致，包括内部 (`status`) 和外部 (`external_status`) 状态字段。
3.  **验证业务流程**: 确保工单处理流程和报销单状态流转 (`pending` -> `processing` -> `waiting_completion` -> `closed`) 符合最新需求，包括由操作历史触发的状态变更。
4.  **测试边界条件**: 确保系统在各种边界条件下 (如重复导入、非法状态转换、报销单关闭后操作限制) 能够正常工作。
5.  **性能测试**: 确保系统在预期负载下能够正常运行。

### 1.2 测试环境

*   开发环境、测试环境、预生产环境。

## 2. 单元测试 (STI - v2)

### 2.1 模型测试

#### 2.1.1 基础模型测试 (Reimbursement, FeeDetail, OperationHistory)

*   **Reimbursement**:
    *   验证 `is_electronic`, `status`, `external_status`, `approval_date`, `approver_name` 字段的存在、默认值和验证。
    *   测试 `status` 状态机的转换逻辑 (`start_processing`, `mark_waiting_completion`, `close`) 及条件 (`all_fee_details_verified?`)。
    *   测试 `update_status_based_on_fee_details!` 的触发逻辑。
    *   测试与 `WorkOrder`, `FeeDetail`, `OperationHistory` 的关联。
*   **FeeDetail**:
    *   验证 `verification_status` 的有效值 (`pending`, `problematic`, `verified`)。
    *   测试 `after_commit :update_reimbursement_status` 回调是否正确触发 `Reimbursement` 的状态检查和转换。
    *   测试与 `Reimbursement` 和 `FeeDetailSelection` 的关联。
*   **OperationHistory**:
    *   测试与 `Reimbursement` 的关联。
    *   验证基础字段 (`document_number`, `operation_type`, `operation_time`, `operator`, `notes`)。

#### 2.1.2 工单模型测试 (WorkOrder STI)

*   **WorkOrder (基类)**:
    *   测试 STI。
    *   测试公共关联 (`reimbursement`, `creator`, polymorphic `fee_detail_selections`, `work_order_status_changes`)。
    *   测试公共回调 (`record_status_change`, `update_reimbursement_status_on_create`)。
    *   验证共享字段 (Req 6/7: `problem_type`, `problem_description`, `remark`, `processing_opinion`) 的存在。
*   **ExpressReceiptWorkOrder**:
    *   验证 `status` 始终为 `completed`。
    *   验证特定字段 (`tracking_number`, `received_at`) 的存在和验证。
*   **AuditWorkOrder**:
    *   测试状态机 (`pending` -> `processing` -> `approved`/`rejected`)。
    *   测试状态转换回调 (`update_associated_fee_details_status`)。
    *   测试 `select_fee_detail(s)` 方法。
    *   测试与 `CommunicationWorkOrder` 的关联。
    *   验证共享字段的读写。
*   **CommunicationWorkOrder**:
    *   测试状态机 (`pending` -> `processing`/`needs_communication` -> `approved`/`rejected`)。
    *   测试状态转换回调 (`update_associated_fee_details_status`)。
    *   测试 `add_communication_record` 方法。
    *   测试 `select_fee_detail(s)` 方法。
    *   测试与 `AuditWorkOrder` 和 `CommunicationRecord` 的关联。
    *   验证共享字段的读写。

#### 2.1.3 关联模型测试

*   **FeeDetailSelection**:
    *   测试与 `FeeDetail` 和 polymorphic `WorkOrder` 的关联。
    *   测试 `verification_status` 的验证。
    *   测试唯一性约束 (scope: `[:fee_detail_id, :work_order_id, :work_order_type]`)。
*   **WorkOrderStatusChange**:
    *   测试与 polymorphic `WorkOrder` 和 `changer` (AdminUser) 的关联。
    *   测试必要字段的验证。
*   **CommunicationRecord**:
    *   测试与 `CommunicationWorkOrder` 的关联。
    *   测试必要字段的验证。

### 2.2 服务测试 (STI - v2)

*   **Import Services**:
    *   `ReimbursementImportService`: 测试创建/更新逻辑，`is_electronic`, `external_status`, `approval_date`, `approver_name` 处理，初始内部 `status` 设置 (考虑 `external_status`)。
    *   `ExpressReceiptImportService`: 测试 `ExpressReceiptWorkOrder` 创建 (status `completed`, `created_by`)，`tracking_number` 提取，`Reimbursement` 状态更新，**重复记录跳过 (reimbursement_id + tracking_number)**，未匹配处理。
    *   `FeeDetailImportService`: 测试 `verification_status` 初始设置 (`pending`)，**重复记录跳过 (document_number + fee_type + amount + fee_date)**，未匹配处理。
    *   `OperationHistoryImportService`: 测试 **重复记录跳过 (document_number + operation_type + operation_time + operator)**，**`Reimbursement` 状态更新 (`close!`) 逻辑 (基于 operation_type='审批' AND notes='审批通过')**，未匹配处理。
*   **Processing Services**:
    *   `AuditWorkOrderService` / `CommunicationWorkOrderService`: 测试状态转换方法 (`start_processing`, `approve`, `reject`, etc.) 是否正确调用状态机事件，**是否正确处理传入的共享字段参数 (problem_type, etc.)**，是否处理 `audit_comment`/`resolution_summary`，是否调用 `FeeDetailVerificationService`。
    *   `CommunicationWorkOrderService`: 测试 `add_communication_record`。
*   **FeeDetailVerificationService**:
    *   测试 `update_verification_status` 是否正确更新 `FeeDetail` 状态。
    *   测试是否阻止在 `Reimbursement` `closed?` 时更新。
    *   测试是否正确触发 `Reimbursement` 的状态检查 (通过 `FeeDetail` 回调)。

## 3. 集成测试 (STI - v2)

验证组件间的交互，特别是完整的业务流程和状态联动。

### 3.1 工单流程测试 (参考 Test Plan v3)

*   **INT-001 (完整报销流程-快递收单到审核完成)**:
    1.  导入报销单 (非电子)。
    2.  导入快递收单 -> 自动创建 `ExpressReceiptWorkOrder` (completed)。
    3.  手动创建 `AuditWorkOrder` (pending)。
    4.  调用服务 `start_processing` -> `AuditWorkOrder` (processing), `FeeDetail` (problematic)。
    5.  调用服务 `approve` -> `AuditWorkOrder` (approved), `FeeDetail` (verified)。
    6.  验证 `Reimbursement.status` 变为 `waiting_completion`。
*   **INT-002 (完整报销流程-包含沟通处理)**:
    1.  导入报销单 (非电子)。
    2.  导入快递收单 -> `ExpressReceiptWorkOrder` (completed)。
    3.  手动创建 `AuditWorkOrder` (pending)。
    4.  调用服务 `start_processing` -> `AuditWorkOrder` (processing), `FeeDetail` (problematic)。
    5.  手动创建 `CommunicationWorkOrder` (pending), 关联 `AuditWorkOrder` 和 `FeeDetail`。
    6.  调用服务 `start_processing` 或 `mark_needs_communication` -> `CommunicationWorkOrder` (processing/needs_communication)。
    7.  调用服务 `approve` -> `CommunicationWorkOrder` (approved), `FeeDetail` (verified)。
    8.  验证 `Reimbursement` 状态变为 `waiting_completion`。
    9.  (或者) 调用服务 `reject` -> `CommunicationWorkOrder` (rejected), `FeeDetail` (problematic)。
*   **INT-004 (费用明细多工单关联测试)**:
    1.  导入报销单和费用明细。
    2.  创建 `AuditWorkOrder`, 关联 `FeeDetail`。
    3.  创建 `CommunicationWorkOrder`, 关联相同 `FeeDetail`。
    4.  处理两个工单至不同状态 (e.g., Audit rejected, Comm approved)。
    5.  验证 `FeeDetail` 状态根据最新处理的工单变化 (应为 `verified` in this case)。
    6.  验证 `FeeDetail` view 能看到两个工单信息 (Req 13)。
*   **INT-005 (操作历史影响报销单状态)**:
    1.  导入报销单。
    2.  导入操作历史 (含 `operation_type='审批'` AND `notes='审批通过'`)。
    3.  验证 `Reimbursement.status` 变为 `closed`，验证 `Reimbursement.external_status` 被记录。
*   **INT-006 (电子发票标志测试)**:
    1.  导入报销单 (含电子发票标签)。
    2.  验证 `Reimbursement.is_electronic` 为 true。
    3.  验证列表/详情页正确显示标志。

### 3.2 数据导入测试 (参考 Test Plan v3)

*   **IMP-R-001/006**: 测试报销单导入 (创建/更新)，`is_electronic`, `external_status`, `approval_date`, `approver_name` 存储，初始内部 `status`。
*   **IMP-E-001/002/004**: 测试快递收单导入，`ExpressReceiptWorkOrder` 创建，`tracking_number` 提取，**重复跳过**，`Reimbursement` 状态更新，未匹配处理。
*   **IMP-F-001/002/004/006**: 测试费用明细导入，初始 `status` (`pending`)，**重复跳过**，未匹配处理。
*   **IMP-O-001/002/004/006**: 测试操作历史导入，**重复跳过**，**`Reimbursement` 状态更新 (`closed`) 基于特定记录**，未匹配处理。
*   **IMP-S-001/002/003**: 测试不同顺序导入的处理。

### 3.3 费用明细验证测试 (参考 Test Plan v3)

*   **FEE-001/002**: 测试在创建工单时选择/关联费用明细。
*   **FEE-003**: 测试工单状态变更 (approve/reject) 触发 `FeeDetail` 状态更新 (`verified`/`problematic`)。
*   **FEE-004**: 测试 `FeeDetail` 关联多个工单及状态跟随最新变化。
*   **FEE-005**: 测试 `FeeDetail` view 显示所有关联工单信息。
*   **FEE-006**: 测试所有 `FeeDetail` 变为 `verified` 后 `Reimbursement.status` 变为 `waiting_completion`。
*   **FEE-007/008**: 测试工单备注/问题标记如何影响 `FeeDetailSelection.verification_comment` 和 `FeeDetail.verification_status`。

## 4. 系统测试 (STI - v2)

使用 Capybara 模拟用户通过 ActiveAdmin 界面的完整操作流程。

*   **测试场景**:
    *   模拟 V3 测试计划中的端到端流程 (INT-001, INT-002, etc.)。
    *   覆盖导入、工单创建 (通过报销单页面)、费用明细选择、**表单字段填写 (包括共享字段)**、状态按钮点击、沟通记录添加、状态联动验证。
*   **示例 (`test/system/complete_workflow_sti_test.rb`)**:
    *   登录 AdminUser。
    *   访问报销单列表，导入报销单/快递单文件。
    *   访问报销单详情页，点击 "新建审核工单"。
    *   填写审核工单表单 (包括选择费用明细，**填写共享字段 problem_type, etc.**)，提交创建。
    *   访问审核工单详情页，点击 "开始处理"。
    *   点击费用明细的 "更新验证状态"，提交验证结果。
    *   (如果需要沟通) 点击 "新建沟通工单"，填写表单，提交创建。
    *   访问沟通工单详情页，添加沟通记录，标记为通过/拒绝。
    *   返回审核工单详情页，点击 "审核通过"/"审核拒绝"。
    *   验证各模型状态和关联数据的正确性 (包括 `external_status`)。
    *   验证报销单状态最终变为 `waiting_completion` 或 `processing` 或 `closed` (根据流程)。

## 5. 性能测试

*   使用 JMeter 等工具进行基准、负载、压力、耐久测试。
*   关注 STI 查询性能，特别是涉及 `work_orders` 表和多态关联的查询。
*   优化策略包括数据库索引 (特别是 `type` 列)、查询优化、缓存等。

## 6. 测试数据准备 (STI - v2)

### 6.1 测试夹具/工厂 (Factories)

*   更新工厂以包含新字段 (`external_status`, shared work order fields)。

```ruby
# Example: spec/factories/reimbursements.rb
FactoryBot.define do
  factory :reimbursement do
    sequence(:invoice_number) { |n| "R#{Time.now.year}#{sprintf('%06d', n)}" }
    document_name { "Test Reimbursement" }
    applicant { "Test User" }
    applicant_id { "TEST001" }
    company { "Test Co" }
    department { "Test Dept" }
    amount { 500.00 }
    receipt_status { "pending" }
    status { "pending" } # Internal status
    external_status { "审批中" } # Example external status
    is_electronic { false }
    approval_date { nil }
    approver_name { nil }

    trait :electronic do
      is_electronic { true }
    end

    trait :received do
       receipt_status { "received" }
       receipt_date { Time.current - 1.day }
    end

     trait :processing do
        status { "processing" }
     end

     trait :waiting_completion do
        status { "waiting_completion" }
     end

     trait :closed do
        status { "closed" }
        external_status { "已付款" } # Example
        approval_date { Time.current - 2.days }
        approver_name { "Test Approver" }
     end
  end
end

# Example: spec/factories/work_orders.rb
FactoryBot.define do
  factory :work_order do
    association :reimbursement
    association :creator, factory: :admin_user
    status { "pending" } # Default status

    # Add shared fields
    problem_type { nil }
    problem_description { nil }
    remark { nil }
    processing_opinion { nil }

    factory :express_receipt_work_order, class: 'ExpressReceiptWorkOrder' do
      type { "ExpressReceiptWorkOrder" }
      status { "completed" }
      sequence(:tracking_number) { |n| "SF#{1000 + n}" }
      received_at { Time.current - 1.day }
      courier_name { "顺丰" }
    end

    factory :audit_work_order, class: 'AuditWorkOrder' do
      type { "AuditWorkOrder" }
      status { "pending" }
      # Default shared fields can be set here if needed

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
        audit_comment { "Test rejection reason" }
      end
    end

    factory :communication_work_order, class: 'CommunicationWorkOrder' do
      type { "CommunicationWorkOrder" }
      association :audit_work_order # Link to a parent audit work order
      status { "pending" }
      communication_method { "system" }
      initiator_role { "auditor" }
      # Default shared fields can be set here if needed

       trait :processing do
        status { "processing" }
      end
       trait :needs_communication do
        status { "needs_communication" }
      end
      trait :approved do
        status { "approved" }
        resolution_summary { "Test resolution" }
      end
       trait :rejected do
        status { "rejected" }
        resolution_summary { "Test rejection reason" }
      end

      # Example of setting shared fields in a trait
      trait :with_problem do
         problem_type { "问题类型A" }
         problem_description { "问题描述1" }
         remark { "需要沟通" }
      end
    end
  end

  factory :fee_detail_selection do
     association :fee_detail
     association :work_order, factory: :audit_work_order # Default association
     verification_status { fee_detail&.verification_status || 'pending' }
  end

  factory :work_order_status_change do
     association :work_order, factory: :audit_work_order # Default association
     from_status { "pending" }
     to_status { "processing" }
     changed_at { Time.current }
     association :changer, factory: :admin_user
  end

  factory :communication_record do
     association :communication_work_order
     content { "Test communication content." }
     communicator_role { "auditor" }
     communicator_name { "Test User" }
     communication_method { "system" }
     recorded_at { Time.current }
  end

end
```

### 6.2 测试数据生成 (Rake Task)

*   更新 `lib/tasks/generate_test_data.rake` 以创建包含新字段 (`external_status`, shared work order fields) 的实例。

## 7. 测试覆盖率目标

*   目标：模型 >90%, 服务 >85%, 控制器/AA >80%, 整体 >85%。
*   使用 SimpleCov 监控。

## 8. 持续集成与部署

*   集成单元测试、集成测试、覆盖率检查到 CI/CD 流程。

## 9. 总结

本测试策略已根据详细的 CSV 分析和 v2 数据库结构进行细化，确保覆盖 STI 模型、导入逻辑 (含重复检查和状态联动)、状态管理和最新业务需求的关键方面。