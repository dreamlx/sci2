# SCI2 工单系统重构概述 (STI 版本 - v2.1)

## 1. 背景与目标

SCI2工单系统是一个财务报销管理系统，主要用于处理报销单的收单、审核和沟通等流程。当前系统是一个基于Rails和ActiveAdmin的MVP，最初计划采用独立拆表的方式重构，但根据最新的需求讨论和测试计划 (`docs/1-2SCI2工单系统测试计划_v3.md`)，决定**采用单表继承 (Single Table Inheritance, STI) 模型**进行重构。

本次重构将采用 **"Drop and Rebuild"** 策略，数据库结构基于 `docs/3.数据导入格式参考.md` 中定义的四种 CSV 文件进行设计。

有关详细的数据库结构设计，请参阅[数据库结构设计](02_database_structure.md)。

### 1.1 重构目标 (基于STI方案 - v2.1)

1.  **统一工单模型**: 使用 `WorkOrder` 作为基类，通过 `type` 字段区分不同工单类型 (快递收单、审核、沟通)。
2.  **精确的数据映射**: 数据库结构精确反映导入文件的字段，并包含应用所需状态字段 (`Reimbursement.status`, `FeeDetail.verification_status`) 和外部系统状态 (`Reimbursement.external_status`)。
3.  **清晰的关联关系**:
    *   `Reimbursement` 与 `WorkOrder` 建立一对多关联。
    *   `FeeDetailSelection` 与 `WorkOrder` 建立多态关联。
    *   `WorkOrderStatusChange` 与 `WorkOrder` 建立多态关联。
4.  **独立状态机**: 为 `Reimbursement`, `AuditWorkOrder`, `CommunicationWorkOrder` 实现独立的状态机，明确状态流转。 状态机用 https://github.com/state-machines/state_machines
5.  **健壮的文件导入**: 使用 `roo` gem 处理导入，实现明确的重复记录处理逻辑 (更新或跳过)，并根据 `OperationHistory` 更新 `Reimbursement` 状态。
6.  **服务对象模式**: 继续使用服务对象封装复杂的业务逻辑。
7.  **ActiveAdmin优化**: 针对STI结构优化ActiveAdmin配置。
8.  **实现最新业务逻辑**: 确保系统行为符合最新的需求讨论记录。

## 2. 重构方案概述 (STI 版本 - v2.1)

### 2.1 数据模型设计 (STI)

采用单表继承，使用 `work_orders` 表存储所有工单类型，并精确映射导入字段。

```mermaid
erDiagram
    Reimbursement ||--o{ WorkOrder : "has many"
    Reimbursement ||--o{ FeeDetail : "has many (via document_number)"
    Reimbursement ||--o{ OperationHistory : "has many (via document_number)"
    WorkOrder ||--o{ FeeDetailSelection : "has many (polymorphic)"
    WorkOrder ||--o{ WorkOrderStatusChange : "has many (polymorphic)"
    FeeDetailSelection }o--|| FeeDetail : "references"
    CommunicationWorkOrder ||--o{ CommunicationRecord : "has many"

    WorkOrder {
        string type PK, FK # STI: ExpressReceiptWorkOrder, AuditWorkOrder, CommunicationWorkOrder
        integer reimbursement_id FK
        string status # Internal status
        integer created_by FK # Link to AdminUser
        # --- Subclass Fields ---
        string tracking_number # ExpressReceipt
        datetime received_at # ExpressReceipt
        string courier_name # ExpressReceipt
        string audit_result # Audit
        text audit_comment # Audit
        datetime audit_date # Audit
        boolean vat_verified # Audit
        string problem_type # Audit/Comm (Req 6/7)
        string problem_description # Audit/Comm (Req 6/7)
        text remark # Audit/Comm (Req 6/7)
        string processing_opinion # Audit/Comm (Req 6/7)
        string communication_method # Communication
        string initiator_role # Communication
        text resolution_summary # Communication
        boolean needs_communication # Communication (布尔标志)
        # --- Timestamps ---
        datetime created_at
        datetime updated_at
    }
    FeeDetailSelection {
        integer id PK
        integer fee_detail_id FK
        integer work_order_id FK
        string work_order_type # Polymorphic type
        text verification_comment # 注意：根据费用明细状态简化设计，已移除verification_status字段
        integer verified_by FK # Link to AdminUser
        datetime verified_at
        datetime created_at
        datetime updated_at
    }
    WorkOrderStatusChange {
        integer id PK
        integer work_order_id FK
        string work_order_type # Polymorphic type
        string from_status
        string to_status
        datetime changed_at
        integer changed_by FK # Link to AdminUser
        datetime created_at
        datetime updated_at
    }
    CommunicationRecord {
        integer id PK
        integer communication_work_order_id FK # Link to WorkOrder (type='CommunicationWorkOrder')
        text content
        string communicator_role
        string communicator_name
        string communication_method
        datetime recorded_at
        datetime created_at
        datetime updated_at
    }
    Reimbursement {
        string invoice_number PK
        boolean is_electronic
        string status # Internal: pending, processing, waiting_completion, closed
        string external_status # Imported status, e.g., "已付款"
        string receipt_status # Imported: pending, received
        datetime receipt_date
        datetime approval_date # Imported
        string approver_name # Imported
        # Other imported fields...
        datetime created_at
        datetime updated_at
    }
    FeeDetail {
         integer id PK
         string document_number FK # Links to Reimbursement.invoice_number
         string verification_status # Internal: pending, problematic, verified
         string fee_type # Imported
         decimal amount # Imported
         date fee_date # Imported
         string payment_method # Imported
         # Other imported fields...
         datetime created_at
         datetime updated_at
    }
    OperationHistory {
        integer id PK
        string document_number FK # Links to Reimbursement.invoice_number
        string operation_type # Imported
        datetime operation_time # Imported
        string operator # Imported
        text notes # Imported
        datetime created_at
        datetime updated_at
    }
```

### 2.2 工单类型与状态 (基于最新需求)

#### 工单基类 (WorkOrder)

基类定义共享字段和方法，包括与报销单的关联、状态变更记录等。

#### 快递收单工单 (ExpressReceiptWorkOrder < WorkOrder)

快递收单工单在导入时自动创建，状态固定为 `completed`，无需状态流转。

#### 审核工单 (AuditWorkOrder < WorkOrder)

审核工单状态流转图：

```
[创建] --> pending --> processing --> rejected/approved
                  \
                   \--> approved/rejected (直接路径，基于处理意见)
```

- **初始状态**：`pending`（创建时）
- **处理中状态**：`processing`（处理意见非空且不是"审核通过"或"无法通过"）
- **结束状态**：
  - `approved`（处理意见为"审核通过"）
  - `rejected`（处理意见为"无法通过"）
- **状态转换触发**：处理意见字段是主要驱动因素

#### 沟通工单 (CommunicationWorkOrder < WorkOrder)

沟通工单状态流转图：

```
[创建] --> pending --> processing --> rejected/approved
                  \
                   \--> approved/rejected (直接路径，基于处理意见)
```

- **初始状态**：`pending`（创建时）
- **处理中状态**：`processing`（处理意见非空且不是"审核通过"或"无法通过"）
- **结束状态**：
  - `approved`（处理意见为"审核通过"）
  - `rejected`（处理意见为"无法通过"）
- **需要沟通标志**：`needs_communication` 实现为布尔字段（boolean），而不是状态值。这样设计允许沟通工单在任何状态下都可以标记为"需要沟通"，更灵活地满足业务需求。

### 2.3 费用明细验证流程 (基于最新需求和简化设计)

费用明细验证状态：`pending` (待处理), `problematic` (有问题), `verified` (已核实)。

- **初始状态**：导入后默认为 `pending`
- **状态变化规则**：
  - 工单状态为 `approved` 时，费用明细状态变为 `verified`
  - 其他任何工单状态，费用明细状态变为 `problematic`
- **多工单关联**：费用明细可关联到多个工单，状态跟随最新处理的工单状态变化
- **状态简化**：根据[费用明细状态简化](10_simplify_fee_detail_status.md)文档，移除了`FeeDetailSelection.verification_status`字段，状态管理完全由`FeeDetail`模型负责

### 2.4 报销单状态流程 (基于最新需求)

报销单内部状态 (`status`)：`pending` (待处理), `processing` (处理中), `waiting_completion` (等待完成), `closed` (已关闭)。
报销单外部状态 (`external_status`)：存储从导入文件 `2.HLY报销单报表.csv` 中读取的 `报销单状态` 字段原始值 (如 "已付款")。

*   **导入时**:
    *   新报销单内部 `status` 设为 `pending` (Req 11)。
    *   `external_status` 存储导入值。
*   **工单创建/处理**: 当有关联工单（审核/沟通）被创建或处理时，内部 `status` 变为 `processing` (Req 11)。
*   **等待完成**: 当报销单下所有费用明细 (`FeeDetail.verification_status`) 都为 `verified` 时，内部 `status` 变为 `waiting_completion` (Req 11)。
*   **关闭**: 当导入的 `OperationHistory` 记录满足特定条件 (如 `operation_type`="审批", `notes`="审批通过") 时，内部 `status` 通过状态机事件强制变为 `closed` (Req 158)。

### 2.5 数据导入与重复处理

*   **Reimbursements**: 根据 `invoice_number` 查找，存在则更新，不存在则创建 (Req 15)。
*   **Express Receipt (Work Order)**: 根据 `reimbursement_id` + `tracking_number` 检查，存在则跳过。
*   **Fee Details**: 根据 `document_number` + `fee_type` + `amount` + `fee_date` 检查，存在则跳过 (Req 14)。
*   **Operation History**: 根据 `document_number` + `operation_type` + `operation_time` + `operator` 检查，存在则跳过 (Req 14)。

### 2.6 实施路线图 (调整后)

1. **数据结构调整阶段**（5月1日 - 5月4日）
   - 设计并实现数据库迁移脚本
   - 创建基础模型结构
   - 实现STI基类和子类

2. **模型实现阶段**（5月5日 - 5月12日）
   - 实现状态机
   - 实现模型关联
   - 实现模型验证和回调
   - 编写单元测试

3. **控制器与视图阶段**（5月13日 - 5月23日）
   - 实现ActiveAdmin资源
   - 实现自定义表单和视图
   - 实现工单处理流程
   - 实现费用明细验证流程

4. **测试与部署阶段**（5月24日 - 6月1日）
   - 执行集成测试
   - 执行系统测试
   - 执行用户验收测试
   - 部署到生产环境

## 3. 相关文档引用

- 有关详细的数据库结构设计，请参阅[数据库结构设计](02_database_structure.md)
- 有关详细的模型实现，请参阅[模型实现](03_model_implementation_updated.md)
- 有关详细的服务实现，请参阅[服务实现](04_service_implementation_updated.md)
- 有关详细的UI设计，请参阅[UI设计](05_activeadmin_ui_design_updated_v3.md)
- 有关详细的ActiveAdmin集成，请参阅[ActiveAdmin集成](05_activeadmin_integration_updated_v3.md)
- 有关详细的测试策略，请参阅[测试策略](06_testing_strategy.md)

## 4. 数据库设计更新

在 `work_orders` 表中添加 `needs_communication` 布尔字段：

```ruby
# Migration: Create WorkOrders (STI)
class CreateWorkOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :work_orders do |t|
      # 现有字段...
      
      # 沟通工单特有字段
      t.string :communication_method
      t.string :initiator_role
      t.text :resolution_summary
      t.boolean :needs_communication, default: false # 添加布尔标志字段
      
      t.timestamps
    end
  end
end
```

## 5. 模型实现更新

在 `CommunicationWorkOrder` 模型中，确保 `needs_communication` 字段可以被正确访问和修改：

```ruby
# app/models/communication_work_order.rb
class CommunicationWorkOrder < WorkOrder
  # 现有代码...
  
  # 确保 needs_communication 字段包含在 ransackable_attributes 中
  def self.subclass_ransackable_attributes
    %w[communication_method initiator_role resolution_summary problem_type problem_description remark processing_opinion needs_communication]
  end
  
  # 添加便捷方法
  def mark_needs_communication!
    update(needs_communication: true)
  end
  
  def unmark_needs_communication!
    update(needs_communication: false)
  end
end
```

## 6. 服务层实现更新

在 `CommunicationWorkOrderService` 中，添加处理 `needs_communication` 布尔标志的方法：

```ruby
# app/services/communication_work_order_service.rb
class CommunicationWorkOrderService
  # 现有代码...
  
  def toggle_needs_communication(value = nil)
    value = !@communication_work_order.needs_communication if value.nil?
    @communication_work_order.update(needs_communication: value)
  end
end
```

## 7. 业务逻辑对齐

更新后的设计完全对齐了业务逻辑需求，特别是：

1. 报销单分为电子发票和纸质发票两种类型，通过 `is_electronic` 布尔字段区分
2. 沟通工单的"需要沟通"标记实现为布尔字段，而非状态值
3. 审核工单和沟通工单都支持直接通过路径，从 `pending` 直接到 `approved`
4. 工单之间无关联关系，只与报销单和费用明细建立关联
5. 处理意见决定工单状态，工单状态影响费用明细状态
6. 所有费用明细 `verified` 时，报销单状态自动变为 `waiting_completion`
7. 费用明细状态管理已简化，移除了`FeeDetailSelection.verification_status`字段，状态管理完全由`FeeDetail`模型负责