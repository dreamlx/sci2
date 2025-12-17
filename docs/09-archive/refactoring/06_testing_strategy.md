# SCI2 工单系统测试策略 (STI 版本 - v3)

有关详细的数据库结构设计，请参阅[数据库结构设计](02_database_structure.md)。
有关详细的模型实现，请参阅[模型实现](03_model_implementation_updated.md)。
有关详细的服务实现，请参阅[服务实现](04_service_implementation_updated.md)。
有关详细的UI设计，请参阅[UI设计](05_activeadmin_ui_design_updated_v3.md)。
有关详细的ActiveAdmin集成，请参阅[ActiveAdmin集成](05_activeadmin_integration_updated_v3.md)。
有关费用明细状态简化的设计，请参阅[费用明细状态简化](10_simplify_fee_detail_status.md)。

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

### 1.3 测试优先级定义

为确保测试工作有序进行，我们定义以下测试优先级：

* **P0 (关键路径)**: 必须100%覆盖，影响核心业务流程的功能
* **P1 (高优先级)**: 必须完成，影响主要功能但不在关键路径上
* **P2 (中优先级)**: 应当完成，影响次要功能
* **P3 (低优先级)**: 可选，边缘情况或性能优化

## 2. 单元测试 (STI - v2)

### 2.1 模型测试 (v3)

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
    *   **[新增]** 测试状态变更对报销单状态的影响，特别是从 `verified` 变为 `problematic` 时的行为。
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
    *   验证共享字段的读写。
*   **CommunicationWorkOrder**:
    *   测试状态机 (`pending` -> `processing`/`needs_communication` -> `approved`/`rejected`)。
    *   测试状态转换回调 (`update_associated_fee_details_status`)。
    *   测试 `add_communication_record` 方法。
    *   测试 `select_fee_detail(s)` 方法。
    *   测试与 `CommunicationRecord` 的关联。
    *   验证共享字段的读写。

#### 2.1.3 关联模型测试

*   **FeeDetailSelection**:
    *   测试与 `FeeDetail` 和 polymorphic `WorkOrder` 的关联。
    *   测试唯一性约束 (scope: `[:fee_detail_id, :work_order_id, :work_order_type]`)。
    *   **注意**: 根据[费用明细状态简化](10_simplify_fee_detail_status.md)文档，已移除`verification_status`字段，状态管理完全由`FeeDetail`模型负责。
*   **WorkOrderStatusChange**:
    *   测试与 polymorphic `WorkOrder` 和 `changer` (AdminUser) 的关联。
    *   测试必要字段的验证。
*   **CommunicationRecord**:
    *   测试与 `CommunicationWorkOrder` 的关联。
    *   测试必要字段的验证。

### 2.2 服务测试 (STI - v3)

*   **Import Services**:
    *   `ReimbursementImportService`: 测试创建/更新逻辑，`is_electronic`, `external_status`, `approval_date`, `approver_name` 处理，初始内部 `status` 设置 (考虑 `external_status`)。
    *   `ExpressReceiptImportService`: 测试 `ExpressReceiptWorkOrder` 创建 (status `completed`, `created_by`)，`tracking_number` 提取，`Reimbursement` 状态更新，**重复记录跳过 (reimbursement_id + tracking_number)**，未匹配处理。
        *   **[新增]** 测试示例：
        ```ruby
        describe "duplicate handling" do
          let!(:reimbursement) { create(:reimbursement) }
          let!(:existing_work_order) do
            create(:express_receipt_work_order,
                  reimbursement: reimbursement,
                  tracking_number: "SF1001")
          end
          
          it "skips duplicate records" do
            # 准备包含重复tracking_number的测试数据
            spreadsheet = double('spreadsheet')
            allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
            allow(spreadsheet).to receive(:row).with(1).and_return(['单号', '操作意见', '操作时间', '操作人'])
            allow(spreadsheet).to receive(:each_with_index).and_yield([reimbursement.invoice_number, '快递单号: SF1001', '2025-01-01 10:00:00', '测试用户'], 1)
            
            expect {
              service.import(spreadsheet)
            }.not_to change(ExpressReceiptWorkOrder, :count)
            
            result = service.import(spreadsheet)
            expect(result[:skipped]).to eq(1)
          end
        end
        ```
    *   `FeeDetailImportService`: 测试 `verification_status` 初始设置 (`pending`)，**重复记录跳过 (document_number + fee_type + amount + fee_date)**，未匹配处理。
        *   **[新增]** 测试重复记录处理逻辑，确保完全相同的费用明细被跳过。
    *   `OperationHistoryImportService`: 测试 **重复记录跳过 (document_number + operation_type + operation_time + operator)**，**`Reimbursement` 状态更新 (`close!`) 逻辑 (基于 operation_type='审批' AND notes='审批通过')**，未匹配处理。
        *   **[新增]** 完善对报销单状态更新的测试，特别是基于"审批通过"的状态变更。
*   **Processing Services**:
    *   `AuditWorkOrderService` / `CommunicationWorkOrderService`: 测试状态转换方法 (`start_processing`, `approve`, `reject`, etc.) 是否正确调用状态机事件，**是否正确处理传入的共享字段参数 (problem_type, etc.)**，是否处理 `audit_comment`/`resolution_summary`，是否调用 `FeeDetailVerificationService`。
    *   `CommunicationWorkOrderService`: 测试 `add_communication_record`。
*   **FeeDetailVerificationService**:
    *   测试 `update_verification_status` 是否正确更新 `FeeDetail` 状态。
    *   测试是否阻止在 `Reimbursement` `closed?` 时更新。
    *   测试是否正确触发 `Reimbursement` 的状态检查 (通过 `FeeDetail` 回调)。
    *   **注意**: 根据[费用明细状态简化](10_simplify_fee_detail_status.md)文档，服务已简化，直接更新`FeeDetail.verification_status`，不再处理`FeeDetailSelection.verification_status`。

## 3. 集成测试 (STI - v3)

验证组件间的交互，特别是完整的业务流程和状态联动。

### 3.1 工单流程测试 (参考 Test Plan v3)

*   **INT-001 (完整报销流程-快递收单到审核完成)**: [P0]
    1.  导入报销单 (非电子)。
    2.  导入快递收单 -> 自动创建 `ExpressReceiptWorkOrder` (completed)。
    3.  手动创建 `AuditWorkOrder` (pending)。
    4.  调用服务 `start_processing` -> `AuditWorkOrder` (processing), `FeeDetail` (problematic)。
    5.  调用服务 `approve` -> `AuditWorkOrder` (approved), `FeeDetail` (verified)。
    6.  验证 `Reimbursement.status` 变为 `waiting_completion`。
    *   **[新增]** 测试示例：
    ```ruby
    describe "INT-001: 完整报销流程-快递收单到审核完成" do
      let!(:reimbursement) { create(:reimbursement) }
      let!(:fee_details) { create_list(:fee_detail, 3, document_number: reimbursement.invoice_number) }
      
      it "completes the full workflow from express receipt to audit approval" do
        # 1. 导入快递收单，创建ExpressReceiptWorkOrder
        express_work_order = create(:express_receipt_work_order, reimbursement: reimbursement)
        reimbursement.reload
        expect(reimbursement.status).to eq('processing')
        
        # 2. 创建审核工单
        audit_work_order = create(:audit_work_order, reimbursement: reimbursement)
        
        # 3. 关联费用明细
        fee_details.each do |fd|
          create(:fee_detail_selection, work_order: audit_work_order, fee_detail: fd)
        end
        
        # 4. 开始处理审核工单
        audit_service = AuditWorkOrderService.new(audit_work_order, create(:admin_user))
        audit_service.start_processing
        
        # 验证费用明细状态变为problematic
        fee_details.each do |fd|
          fd.reload
          expect(fd.verification_status).to eq('problematic')
        end
        
        # 5. 审核通过
        audit_service.approve
        
        # 验证费用明细状态变为verified
        fee_details.each do |fd|
          fd.reload
          expect(fd.verification_status).to eq('verified')
        end
        
        # 验证报销单状态变为waiting_completion
        reimbursement.reload
        expect(reimbursement.status).to eq('waiting_completion')
      end
    end
    ```
*   **INT-002 (完整报销流程-包含沟通处理)**: [P0]
    1.  导入报销单 (非电子)。
    2.  导入快递收单 -> `ExpressReceiptWorkOrder` (completed)。
    3.  手动创建 `AuditWorkOrder` (pending)。
    4.  调用服务 `start_processing` -> `AuditWorkOrder` (processing), `FeeDetail` (problematic)。
    5.  手动创建 `CommunicationWorkOrder` (pending), 关联 `FeeDetail`。
    6.  调用服务 `start_processing` 或 `mark_needs_communication` -> `CommunicationWorkOrder` (processing/needs_communication)。
    7.  调用服务 `approve` -> `CommunicationWorkOrder` (approved), `FeeDetail` (verified)。
    8.  验证 `Reimbursement` 状态变为 `waiting_completion`。
    9.  (或者) 调用服务 `reject` -> `CommunicationWorkOrder` (rejected), `FeeDetail` (problematic)。
    *   **[新增]** 实现完整测试场景，包括审核拒绝后的沟通处理流程。
*   **INT-004 (费用明细多工单关联测试)**: [P1]
    1.  导入报销单和费用明细。
    2.  创建 `AuditWorkOrder`, 关联 `FeeDetail`。
    3.  创建 `CommunicationWorkOrder`, 关联相同 `FeeDetail`。
    4.  处理两个工单至不同状态 (e.g., Audit rejected, Comm approved)。
    5.  验证 `FeeDetail` 状态根据最新处理的工单变化 (应为 `verified` in this case)。
    6.  验证 `FeeDetail` view 能看到两个工单信息 (Req 13)。
*   **INT-005 (操作历史影响报销单状态)**: [P1]
    1.  导入报销单。
    2.  导入操作历史 (含 `operation_type='审批'` AND `notes='审批通过'`)。
    3.  验证 `Reimbursement.status` 变为 `closed`，验证 `Reimbursement.external_status` 被记录。
*   **INT-006 (电子发票标志测试)**: [P2]
    1.  导入报销单 (含电子发票标签)。
    2.  验证 `Reimbursement.is_electronic` 为 true。
    3.  验证列表/详情页正确显示标志。

### 3.2 数据导入测试 (参考 Test Plan v3)

*   **IMP-R-001/006**: [P0] 测试报销单导入 (创建/更新)，`is_electronic`, `external_status`, `approval_date`, `approver_name` 存储，初始内部 `status`。
*   **IMP-E-001/002/004**: [P0] 测试快递收单导入，`ExpressReceiptWorkOrder` 创建，`tracking_number` 提取，**重复跳过**，`Reimbursement` 状态更新，未匹配处理。
*   **IMP-F-001/002/004/006**: [P0] 测试费用明细导入，初始 `status` (`pending`)，**重复跳过**，未匹配处理。
*   **IMP-O-001/002/004/006**: [P0] 测试操作历史导入，**重复跳过**，**`Reimbursement` 状态更新 (`closed`) 基于特定记录**，未匹配处理。
*   **IMP-S-001/002/003**: [P1] 测试不同顺序导入的处理。
    *   **[新增]** 实现导入顺序测试，验证系统能够处理不同顺序的导入操作。

### 3.3 费用明细验证测试 (参考 Test Plan v3)

*   **FEE-001/002**: [P1] 测试在创建工单时选择/关联费用明细。
*   **FEE-003**: [P0] 测试工单状态变更 (approve/reject) 触发 `FeeDetail` 状态更新 (`verified`/`problematic`)。
*   **FEE-004**: [P1] 测试 `FeeDetail` 关联多个工单及状态跟随最新变化。
*   **FEE-005**: [P1] 测试 `FeeDetail` view 显示所有关联工单信息。
*   **FEE-006**: [P0] 测试所有 `FeeDetail` 变为 `verified` 后 `Reimbursement.status` 变为 `waiting_completion`。
*   **FEE-007/008**: [P1] 测试工单备注/问题标记如何影响 `FeeDetailSelection.verification_comment` 和 `FeeDetail.verification_status`。
    *   **注意**: 根据[费用明细状态简化](10_simplify_fee_detail_status.md)文档，状态管理完全由`FeeDetail`模型负责。

## 4. 系统测试 (STI - v3)

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
*   **[新增]** 定义性能测试指标：
    * 导入1000条记录的响应时间 < 30秒
    * 工单列表页面加载时间 < 2秒
    * 报销单详情页面加载时间 < 1秒
    * 工单状态变更操作响应时间 < 1秒

## 6. 测试数据准备 (STI - v3)

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
     # 注意：根据费用明细状态简化设计，已移除verification_status字段
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
*   **[新增]** 创建测试数据生成脚本，支持生成不同场景的测试数据集：
    * 基础数据集：包含报销单、费用明细、操作历史
    * 完整流程数据集：包含完整的工单处理流程
    * 性能测试数据集：包含大量数据用于性能测试

## 7. 测试覆盖率目标

*   目标：模型 >90%, 服务 >85%, 控制器/AA >80%, 整体 >85%。
*   使用 SimpleCov 监控。
*   **[新增]** 测试覆盖率目标细化：
    * **关键路径**：100%覆盖
    * **模型**：
        * `Reimbursement`, `WorkOrder`, `FeeDetail`: >95%
        * 其他模型: >90%
    * **服务**：
        * 导入服务: >90%
        * 工单处理服务: >90%
        * 其他服务: >85%
    * **控制器/ActiveAdmin**：
        * 工单相关资源: >85%
        * 报销单相关资源: >85%
        * 其他资源: >80%

## 8. 持续集成与部署

*   集成单元测试、集成测试、覆盖率检查到 CI/CD 流程。
*   **[新增]** 测试自动化策略：
    * 每次提交运行单元测试
    * 每日运行完整测试套件（包括集成测试和系统测试）
    * 每周运行性能测试
    * 测试失败时自动通知开发团队
    * 测试覆盖率低于目标时阻止合并

## 9. 总结

## 9. 测试计划实施路线图

**[新增]** 按照以下路线图实施测试计划：

1. **第1阶段（高优先级）**：
   * 完善模型测试，特别是FeeDetail的回调测试
   * 实现ExpressReceiptImportService和FeeDetailImportService测试
   * 实现完整业务流程集成测试(INT-001, INT-002)
   * 实现费用明细状态与报销单状态联动测试

2. **第2阶段（中优先级）**：
   * 实现导入顺序测试(IMP-S-001/002/003)
   * 完善电子发票标志测试(INT-006)
   * 开发基本的系统测试

3. **第3阶段（低优先级）**：
   * 实现性能测试
   * 完善边界条件测试
   * 优化测试覆盖率

## 10. 总结

本测试策略已根据详细的 CSV 分析和 v3 数据库结构进行细化，确保覆盖 STI 模型、导入逻辑 (含重复检查和状态联动)、状态管理和最新业务需求的关键方面。通过实施本测试策略，我们可以确保系统符合最新的业务需求，特别是单表继承模型下的工单处理流程和状态联动逻辑。

## 11. 相关文档引用

- 有关详细的数据库结构设计，请参阅[数据库结构设计](02_database_structure.md)
- 有关详细的模型实现，请参阅[模型实现](03_model_implementation_updated.md)
- 有关详细的服务实现，请参阅[服务实现](04_service_implementation_updated.md)
- 有关详细的UI设计，请参阅[UI设计](05_activeadmin_ui_design_updated_v3.md)
- 有关详细的ActiveAdmin集成，请参阅[ActiveAdmin集成](05_activeadmin_integration_updated_v3.md)
- 有关费用明细状态简化的设计，请参阅[费用明细状态简化](10_simplify_fee_detail_status.md)