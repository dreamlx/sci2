# Refactoring Documentation Update Plan (STI Alignment)

This plan outlines the necessary updates to the documentation in `docs/refactoring/` to align with the latest business requirements, primarily the shift back to a Single Table Inheritance (STI) model for Work Orders.

**Source Requirements:**

initial request

            新需求变动来了， 然后我继续补充：

            现状4个导入表：

            报销单，核心是分电子发票和纸质发票， 所以在导入后需要另外加一个电子发票标志字段，是否电子发票人工勾选
            2 导入快递收单，根据导入快递单直接生成工单，工单操作人就是导入人（mvp阶段就是rails 里面的 current user）， 工单直接显示状态完成completed
            3 原来分开设计的快递收单工单/审核工单/沟通工单，还是改回单表继承。 现在确认3个工单内部格式大部分一样
            4 工单状态正常基本就是pending → processing → completed
            5 审核工单必须在报销单 view 界面创建，一个报销单有多个审核工单，每个审核工单必须选择1-n条费用明细
            6 审核工单form结构： 选择中的费用明细多条， 问题类型下拉列表， 问题说明下拉列表， 备注说明text， 处理意见：下拉列表（工单状态改变），操作人自动填写：默认当前用户， 保存后改变费用明细状态。
            7 沟通工单form结构和审核工单完全一样，唯一区别就是审核工单是一组人做，沟通工单是另外一组人。所以才有不同的区别
            8 费用明细导入后有一个状态，默认pending， 然后根据审核工单和沟通工单状态改变，要么problematic，要么verified
            9 审核工单和沟通工单都直接和报销单关联，报销单对应3个工单，工单之间没有关联关系
            10 审核工单状态变化就是 pending→processing(如果工单是正在处理中) → rejected or approved(人工操作到这里结束，还有问题另外新开工单)
            11 报销单导入后默认状态pending，有工单→processing, 当全部明细费用状态都是verified的时候状态改为”等待完成” 增加一个状态
            12 沟通工单状态： 默认pending → processing | needs_communication → → rejected or approved(人工操作到这里结束，还有问题另外新开工单)
            13 费用明细关联多个工单（审核工单，沟通工单），点开明细view 可以看到全部相关工单的问题和备注说明
            14 操作历史记录导入时候需要判断一下是否重复导入，完全相同记录条目就跳过。费用明细表导入逻辑也一样
            15 报销单导入如果重复就是覆盖更新，以invoice number 为唯一关键字
            好了以上帮我整理一下逻辑，然后比较一下和原来测试计划中的业务逻辑有哪些变化和补充


*   需求讨论记录 (provided in initial request)
*   `docs/1-2SCI2工单系统测试计划_v3.md`

**Core Change:** Revert from separate Work Order tables to an STI model based on `WorkOrder`.

---

## File-by-File Update Plan:

**1. `docs/refactoring/01_overview.md` (重构概述)**

*   **Rewrite Background & Goals:** Update to reflect the decision to use STI. The primary goal is now implementing a robust STI structure.
*   **Update Architecture Diagram (Mermaid ERD):** Replace the ERD to show:
    *   `Reimbursement` -> `WorkOrder` (one-to-many)
    *   `WorkOrder` with a `type` column (for STI subclasses).
    *   `FeeDetailSelection` -> `WorkOrder` (polymorphic many-to-one).
    *   `WorkOrderStatusChange` -> `WorkOrder` (polymorphic many-to-one).
    *   `CommunicationRecord` -> `CommunicationWorkOrder` (many-to-one).
    *   Remove direct links between specific work order types.
    ```mermaid
    erDiagram
        Reimbursement ||--o{ WorkOrder : "has many"
        Reimbursement ||--o{ FeeDetail : "has many"
        Reimbursement ||--o{ OperationHistory : "has many"
        WorkOrder ||--o{ FeeDetailSelection : "has many (polymorphic)"
        WorkOrder ||--o{ WorkOrderStatusChange : "has many (polymorphic)"
        FeeDetailSelection }o--|| FeeDetail : "references"
        CommunicationWorkOrder ||--o{ CommunicationRecord : "has many"

        WorkOrder {
            string type # ExpressReceiptWorkOrder, AuditWorkOrder, CommunicationWorkOrder
            integer reimbursement_id FK
            string status
            integer created_by
            # Other common fields...
        }
        FeeDetailSelection {
            integer fee_detail_id FK
            integer work_order_id FK
            string work_order_type
            string verification_status
            text verification_comment
            # Other fields...
        }
        WorkOrderStatusChange {
            integer work_order_id FK
            string work_order_type
            string from_status
            string to_status
            datetime changed_at
            integer changed_by
            # Other fields...
        }
        CommunicationRecord {
            integer communication_work_order_id FK
            text content
            # Other fields...
        }
        Reimbursement {
            string invoice_number PK
            boolean is_electronic
            string status # pending, processing, 等待完成, closed
            # Other fields...
        }
        FeeDetail {
             string document_number FK
             string verification_status # pending, problematic, verified
             # Other fields...
        }
    ```
*   **Update Work Order Types & Statuses:**
    *   Explain the STI approach (`WorkOrder` base class).
    *   Update status flows per Requirements 2, 10, 12:
        *   **ExpressReceiptWorkOrder:** Created with status `completed`.
        *   **AuditWorkOrder:** `pending` -> `processing` -> `rejected` / `approved`.
        *   **CommunicationWorkOrder:** `pending` -> `processing` / `needs_communication` -> `rejected` / `approved`.
    *   Add Mermaid state diagrams for Audit and Communication WOs:
        *   **AuditWorkOrder Status:**
            ```mermaid
            stateDiagram-v2
                direction LR
                [*] --> pending
                pending --> processing : Start Processing
                processing --> approved : Approve
                processing --> rejected : Reject
                approved --> [*]
                rejected --> [*]
            ```
        *   **CommunicationWorkOrder Status:**
            ```mermaid
            stateDiagram-v2
                direction LR
                [*] --> pending
                pending --> processing : Start Processing
                pending --> needs_communication : Need Communication
                processing --> approved : Approve
                processing --> rejected : Reject
                needs_communication --> approved : Approve
                needs_communication --> rejected : Reject
                approved --> [*]
                rejected --> [*]
            ```
*   **Update Fee Detail Verification Flow:** Simplify to `pending` -> `problematic` / `verified` (Req 8).
*   **Update Reimbursement Status Flow:** Add the "等待完成" status (Req 11).
*   **Revise Implementation Roadmap:** Adjust based on STI.

**2. `docs/refactoring/02_database_structure.md` (数据库结构)**

*   **Rewrite Table Design:**
    *   Define a single `work_orders` table with common fields and `type: string`. Include specific subclass fields (nullable).
    *   Update `fee_detail_selections` for polymorphic `work_order` association (`work_order_id`, `work_order_type`).
    *   Update `work_order_status_changes` for polymorphic `work_order` association.
    *   Add `is_electronic: boolean` and `status: string` to `reimbursements`.
    *   Remove designs for separate WO tables.
*   **Rewrite Migration Plan:** Show migrations for `work_orders` (STI), modifying `fee_detail_selections` (poly), adding fields to `reimbursements`. Remove old migrations.
*   **Update Indexing/Constraints:** Reflect STI structure.

**3. `docs/refactoring/03_model_implementation.md` (模型实现)**

*   **Rewrite Work Order Models:**
    *   Define `WorkOrder < ApplicationRecord` base class.
    *   Define STI subclasses: `ExpressReceiptWorkOrder`, `AuditWorkOrder`, `CommunicationWorkOrder`.
    *   Implement associations and state machines in subclasses per updated flows.
    *   Update `FeeDetailSelection` to use `belongs_to :work_order, polymorphic: true`.
    *   Update `WorkOrderStatusChange` to use `belongs_to :work_order, polymorphic: true`.
    *   Add `is_electronic` and `status` (with logic/state machine) to `Reimbursement`.
*   **Update Model Diagram (Mermaid Class Diagram):** Show STI inheritance and polymorphic links.

**4. `docs/refactoring/04_service_implementation.md` (服务实现)**

*   **Update Import Services:**
    *   `ReimbursementImportService`: Handle `is_electronic`, update-on-duplicate (Req 15).
    *   `ExpressReceiptImportService`: Create `ExpressReceiptWorkOrder` directly (status `completed`, correct `created_by`) (Req 2).
    *   `FeeDetailImportService`: Skip duplicates (Req 14), use polymorphic association.
    *   `OperationHistoryImportService`: Skip duplicates (Req 14), update `Reimbursement` status logic.
*   **Update Work Order Processing Services:**
    *   Refactor services (`AuditWorkOrderService`, etc.) for the STI model.
    *   Update state transition logic per new state machines.
    *   Ensure services update `FeeDetail` status (`problematic`/`verified`) (Req 8).
    *   Implement logic to update `Reimbursement` status to "等待完成" (Req 11).
*   **Update `FeeDetailVerificationService`:** Align with `pending` -> `problematic`/`verified` flow, handle `Reimbursement` status updates.

**5. `docs/refactoring/05_activeadmin_integration.md` (ActiveAdmin 集成)**

*   **Update Resource Registration:** Adapt resources for the STI `WorkOrder` model (either base class with scopes/filters or individual subclasses).
*   **Update Forms:** Include fields from Requirements 6 & 7 (dropdowns, remarks text).
*   **Update Index/Show/Actions:** Reflect STI structure, new fields (`is_electronic`, `Reimbursement` status), and new state machine actions.
*   **Update Custom Views:** Adapt import forms, approval forms, etc.

**6. `docs/refactoring/06_testing_strategy.md` (测试策略)**

*   **Align with Test Plan v3:** Ensure content matches `docs/1-2SCI2工单系统测试计划_v3.md`, including phase 1 limitations and removed tests.
*   **Update Unit Tests:** Describe tests for STI models, state machines, polymorphic associations.
*   **Update Service Tests:** Describe tests for updated import/processing logic.
*   **Update Integration/System Tests:** Describe tests for new end-to-end STI workflows, referencing test IDs from v3 plan.