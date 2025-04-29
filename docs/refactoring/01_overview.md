# SCI2 工单系统重构概述 (STI 版本 - v2)

## 1. 背景与目标

SCI2工单系统是一个财务报销管理系统，主要用于处理报销单的收单、审核和沟通等流程。当前系统是一个基于Rails和ActiveAdmin的MVP，最初计划采用独立拆表的方式重构，但根据最新的需求讨论和测试计划 (`docs/1-2SCI2工单系统测试计划_v3.md`)，决定**采用单表继承 (Single Table Inheritance, STI) 模型**进行重构。

本次重构将采用 **"Drop and Rebuild"** 策略，数据库结构基于 `docs/3.数据导入格式参考.md` 中定义的四种 CSV 文件进行设计。

### 1.1 重构目标 (基于STI方案 - v2)

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

## 2. 重构方案概述 (STI 版本 - v2)

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
        # --- Timestamps ---
        datetime created_at
        datetime updated_at
    }
    FeeDetailSelection {
        integer id PK
        integer fee_detail_id FK
        integer work_order_id FK
        string work_order_type # Polymorphic type
        string verification_status # Synced/Redundant status
        text verification_comment
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

*(状态机图表和描述保持不变，参考 `docs/refactoring/01_overview.md` 的 v1 版本)*

#### 工单基类 (WorkOrder)
#### 快递收单工单 (ExpressReceiptWorkOrder < WorkOrder)
#### 审核工单 (AuditWorkOrder < WorkOrder)
#### 沟通工单 (CommunicationWorkOrder < WorkOrder)

### 2.3 费用明细验证流程 (基于最新需求)

*(描述保持不变，参考 `docs/refactoring/01_overview.md` 的 v1 版本)*
状态：`pending` (待处理), `problematic` (有问题), `verified` (已核实)。

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

*(保持不变，参考 `docs/refactoring/01_overview.md` 的 v1 版本)*

## 3. 文档结构

*(保持不变，参考 `docs/refactoring/01_overview.md` 的 v1 版本)*