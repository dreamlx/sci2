# SCI2 工单系统数据库结构设计 (STI - Drop & Rebuild - v2.1)

## 0 补充更新说明

需要添加的字段：

沟通工单的 needs_communication 标志字段（测试用例 WF-C-003 要求）
已在 work_orders 表中添加此字段：

t.boolean :needs_communication, default: false # 用于沟通工单


## 1. 设计策略与相关文档

这些数据库结构的模型实现详情，请参阅[模型实现](03_model_implementation_updated.md)。
关于费用明细状态的简化设计，请参阅[费用明细状态简化](10_simplify_fee_detail_status.md)。

本数据库结构设计基于 **"Drop and Rebuild"** 策略。系统将从干净的数据库开始，并通过导入 `docs/3.数据导入格式参考.md` 中定义的四种 CSV 文件 (`2.HLY报销单报表.csv`, `1.HLY快递收单导出数据.csv`, `4.HLY单据费用明细报表.csv`, `3.HLY每单操作历史数据.csv`) 来填充初始数据。

核心设计采用 **单表继承 (STI)** 模型管理工单 (`work_orders` 表)。


## 2. 表结构设计

### 2.1 核心导入映射表

#### 报销单表 (reimbursements)

*   基于 `2.HLY报销单报表.csv` 结构，并添加应用所需字段。

```
id: integer (PK)
invoice_number: string (Unique, 来自 "报销单单号")
document_name: string (来自 "单据名称")
applicant: string (来自 "报销单申请人")
applicant_id: string (来自 "报销单申请人工号")
company: string (来自 "申请人公司")
department: string (来自 "申请人部门")
receipt_status: string (来自 "收单状态", e.g., 'pending', 'received')
receipt_date: datetime (来自 "收单日期", nullable)
submission_date: datetime (来自 "提交报销日期", nullable)
amount: decimal (来自 "报销金额（单据币种）")
is_electronic: boolean (根据 "单据标签" 判断, default: false, null: false)
status: string (应用内部状态, e.g., 'pending', 'processing', 'waiting_completion', 'closed', default: 'pending', null: false)
external_status: string (来自 "报销单状态", e.g., "已付款", nullable, 存储原始外部状态)
approval_date: datetime (来自 "报销单审核通过日期", nullable)
approver_name: string (来自 "审核通过人", nullable)
# --- 其他可选导入字段 (如果应用逻辑需要) ---
related_application_number: string (来自 "关联申请单号")
accounting_date: date (来自 "记账日期")
document_tags: string (来自 "单据标签" - 原始值)
# --- Timestamps ---
created_at: datetime
updated_at: datetime
```
*   **Duplicate Handling**: Records are found or initialized based on `invoice_number`. Existing records are updated.

#### 费用明细表 (fee_details)

*   基于 `4.HLY单据费用明细报表.csv` 结构，并添加应用所需字段。

```
id: integer (PK)
document_number: string (FK, references reimbursements.invoice_number, 来自 "报销单单号")
fee_type: string (来自 "费用类型")
amount: decimal (来自 "原始金额")
fee_date: date (来自 "费用发生日期")
payment_method: string (来自 "弹性字段11", nullable)
verification_status: string [pending, problematic, verified] (应用内部状态, default: 'pending', null: false)
# --- 其他可选导入字段 ---
month_belonging: string (来自 "所属月")
first_submission_date: datetime (来自 "首次提交日期")
# --- Timestamps ---
created_at: datetime
updated_at: datetime
```
*   **Duplicate Handling**: Import skips records where `document_number`, `fee_type`, `amount`, and `fee_date` already exist.

#### 操作历史表 (operation_histories)

*   基于 `3.HLY每单操作历史数据.csv` 结构。

```
id: integer (PK)
document_number: string (FK, references reimbursements.invoice_number, 来自 "单据编号")
operation_type: string (来自 "操作类型")
operation_time: datetime (来自 "操作日期")
operator: string (来自 "操作人")
notes: text (来自 "操作意见", nullable)
# --- 其他可选导入字段 ---
form_type: string (来自 "表单类型")
operation_node: string (来自 "操作节点")
# --- Timestamps ---
created_at: datetime
updated_at: datetime
```
*   **Duplicate Handling**: Import skips records where `document_number`, `operation_type`, `operation_time`, and `operator` already exist.
*   **Status Impact**: The import service for this table will parse `operation_type` and `notes` to trigger `reimbursement.close!` when conditions like "审批通过" are met.

### 2.2 工单表 (work_orders - STI)

*   存储所有类型的工单，通过 `type` 字段区分。
*   包含公共字段及所有子类所需字段 (nullable)。

```
id: integer (PK)
reimbursement_id: integer (FK, references reimbursements.id, null: false)
type: string (STI column, e.g., 'ExpressReceiptWorkOrder', 'AuditWorkOrder', 'CommunicationWorkOrder', null: false)
status: string (状态, 根据子类状态机定义, null: false)
created_by: integer (FK, references admin_users.id, nullable, 操作人ID)

# --- Subclass Fields (nullable) ---
# ExpressReceiptWorkOrder fields (来自 1.HLY快递收单导出数据.csv)
tracking_number: string (从 "操作意见" 提取)
received_at: datetime (来自 "操作时间")
courier_name: string (可推断或留空)

# AuditWorkOrder fields (应用内部字段 + Req 6)
audit_result: string
audit_comment: text
audit_date: datetime
vat_verified: boolean
problem_type: string (来自 Req 6 下拉列表)
problem_description: string (来自 Req 6 下拉列表)
remark: text (来自 Req 6 备注说明)
processing_opinion: string (来自 Req 6 处理意见下拉列表)

# CommunicationWorkOrder fields (应用内部字段 + Req 7)
communication_method: string
initiator_role: string
resolution_summary: text
needs_communication: boolean (default: false) # 布尔标志，非状态值
# Req 7 表单字段与 AuditWorkOrder 相同，复用上面 Audit 的字段

# --- Timestamps ---
created_at: datetime
updated_at: datetime
```
*   **Duplicate Handling (`ExpressReceiptWorkOrder`)**: Import skips creating if a record with the same `reimbursement_id` and `tracking_number` exists.

### 2.3 关联表

#### 费用明细选择表 (fee_detail_selections)

*   多态关联 `work_orders` 和 `fee_details`。

```
id: integer (PK)
fee_detail_id: integer (FK, references fee_details.id, null: false)
work_order_id: integer (FK, references work_orders.id, null: false)
work_order_type: string (多态关联类型, null: false)
verification_comment: text (工单内对此明细的备注)
verified_by: integer (FK, references admin_users.id, nullable)
verified_at: datetime (nullable)
created_at: datetime
updated_at: datetime
```

#### 沟通记录表 (communication_records)

*   关联到 `work_orders` 表中 `type` 为 `CommunicationWorkOrder` 的记录。

```
id: integer (PK)
communication_work_order_id: integer (FK, references work_orders.id, null: false) # 逻辑上指向 CommunicationWorkOrder
content: text (null: false)
communicator_role: string
communicator_name: string
communication_method: string
recorded_at: datetime (null: false)
created_at: datetime
updated_at: datetime
```

#### 工单状态变更表 (work_order_status_changes)

*   多态关联到 `work_orders` 表，记录状态变更历史。

```
id: integer (PK)
work_order_id: integer (FK, references work_orders.id, null: false)
work_order_type: string (多态关联类型, null: false)
from_status: string (nullable)
to_status: string (null: false)
changed_at: datetime (null: false)
changed_by: integer (FK, references admin_users.id, nullable)
created_at: datetime
updated_at: datetime
```

## 3. 数据库迁移计划 (Drop & Rebuild)

此计划假设从零开始创建所有表结构。

```ruby
# Migration 1: Create Reimbursements
class CreateReimbursements < ActiveRecord::Migration[7.0]
  def change
    create_table :reimbursements do |t|
      t.string :invoice_number, null: false, index: { unique: true }
      t.string :document_name
      t.string :applicant
      t.string :applicant_id
      t.string :company
      t.string :department
      t.string :receipt_status
      t.datetime :receipt_date
      t.datetime :submission_date
      t.decimal :amount, precision: 10, scale: 2 # Adjust precision/scale as needed
      t.boolean :is_electronic, default: false, null: false
      t.string :status, default: 'pending', null: false, index: true
      t.string :external_status # Store raw external status
      t.datetime :approval_date
      t.string :approver_name
      # Add other optional columns if needed
      t.timestamps
    end
  end
end

# Migration 2: Create FeeDetails
class CreateFeeDetails < ActiveRecord::Migration[7.0]
  def change
    create_table :fee_details do |t|
      t.string :document_number, null: false, index: true
      t.string :fee_type
      t.decimal :amount, precision: 10, scale: 2
      t.date :fee_date
      t.string :payment_method
      t.string :verification_status, default: 'pending', null: false, index: true
      # Add other optional columns if needed
      t.timestamps
    end
    # Add foreign key constraint if using invoice_number as FK target
    # add_foreign_key :fee_details, :reimbursements, column: :document_number, primary_key: :invoice_number
  end
end

# Migration 3: Create OperationHistories
class CreateOperationHistories < ActiveRecord::Migration[7.0]
  def change
    create_table :operation_histories do |t|
      t.string :document_number, null: false, index: true
      t.string :operation_type
      t.datetime :operation_time
      t.string :operator
      t.text :notes
      # Add other optional columns if needed
      t.timestamps
    end
    # Add foreign key constraint if using invoice_number as FK target
    # add_foreign_key :operation_histories, :reimbursements, column: :document_number, primary_key: :invoice_number
  end
end

# Migration 4: Create WorkOrders (STI)
class CreateWorkOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :work_orders do |t|
      t.references :reimbursement, foreign_key: true, null: false # Assumes reimbursements.id is PK
      t.string :type, null: false, index: true # STI column
      t.string :status, null: false, index: true
      t.references :admin_user, foreign_key: true, null: true, column: :created_by

      # ExpressReceiptWorkOrder fields
      t.string :tracking_number, index: true # Index for duplicate check
      t.datetime :received_at
      t.string :courier_name

      # AuditWorkOrder fields
      t.string :audit_result
      t.text :audit_comment
      t.datetime :audit_date
      t.boolean :vat_verified
      t.string :problem_type
      t.string :problem_description
      t.text :remark
      t.string :processing_opinion

      # CommunicationWorkOrder fields
      t.string :communication_method
      t.string :initiator_role
      t.text :resolution_summary
      t.boolean :needs_communication, default: false # 添加布尔标志字段

      t.timestamps
    end
  end
end

# Migration 5: Create FeeDetailSelections
class CreateFeeDetailSelections < ActiveRecord::Migration[7.0]
  def change
    create_table :fee_detail_selections do |t|
      t.references :fee_detail, foreign_key: true, null: false
      t.references :work_order, polymorphic: true, null: false, index: true
      t.text :verification_comment
      t.references :admin_user, foreign_key: true, null: true, column: :verified_by
      t.datetime :verified_at
      t.timestamps
    end
    # Optional: Add unique index
    # add_index :fee_detail_selections, [:fee_detail_id, :work_order_id, :work_order_type], unique: true, name: 'index_fee_details_selections_on_fee_and_work_order'
  end
end

# Migration 6: Create CommunicationRecords
class CreateCommunicationRecords < ActiveRecord::Migration[7.0]
  def change
    create_table :communication_records do |t|
      t.references :communication_work_order, null: false, foreign_key: { to_table: :work_orders }
      t.text :content, null: false
      t.string :communicator_role
      t.string :communicator_name
      t.string :communication_method
      t.datetime :recorded_at, null: false
      t.timestamps
    end
  end
end

# Migration 7: Create WorkOrderStatusChanges
class CreateWorkOrderStatusChanges < ActiveRecord::Migration[7.0]
  def change
    create_table :work_order_status_changes do |t|
      t.references :work_order, polymorphic: true, null: false, index: true
      t.string :from_status
      t.string :to_status, null: false
      t.datetime :changed_at, null: false
      t.references :admin_user, foreign_key: true, null: true, column: :changed_by
      t.timestamps
    end
  end
end
```

## 4. 索引优化

*   **`reimbursements`**: `invoice_number` (unique), `status`, `external_status`, `is_electronic`.
*   **`fee_details`**: `document_number`, `verification_status`, `fee_date`, `[:document_number, :fee_type, :amount, :fee_date]` (for duplicate check).
*   **`operation_histories`**: `document_number`, `operation_time`, `[:document_number, :operation_type, :operation_time, :operator]` (for duplicate check).
*   **`work_orders`**: `type`, `status`, `reimbursement_id`, `created_by`, `[:reimbursement_id, :tracking_number]` (for express duplicate check).
*   **`fee_detail_selections`**: `[:work_order_id, :work_order_type]`, `fee_detail_id`, optional unique index.
*   **`communication_records`**: `communication_work_order_id`.
*   **`work_order_status_changes`**: `[:work_order_id, :work_order_type]`, `changed_at`, `changed_by`.

## 5. 数据库约束

*   **外键**: Defined in migrations where applicable (non-polymorphic). Assumes `reimbursements.id` is PK.
*   **非空**: Defined in migrations (`null: false`).
*   **唯一**: `reimbursements.invoice_number`, optional `fee_detail_selections` index.

## 6. 数据库设计考虑因素

*   **STI**: Simplifies core model, requires careful indexing on `type`. Table can become wide.
*   **Import Focus**: Structure prioritizes mapping from import files. Duplicate checks defined based on import data.
*   **Status Management**: Internal `reimbursements.status` is managed by application logic (state machine). `reimbursements.external_status` stores the source system status. The `OperationHistoryImportService` is responsible for triggering the internal `closed` state based on specific history events (e.g., "审批通过").
*   **FKs**: Assumes standard integer primary keys (`id`) and foreign keys referencing `id`. Using `invoice_number` as a primary/foreign key target is possible but generally less conventional in Rails.

## 7. 处理意见与状态关系

处理意见（`processing_opinion`）字段与工单状态（`status`）的关系如下：

* 处理意见为空：工单状态保持为 `pending`
* 处理意见为"审核通过"：工单状态变为 `approved`
* 处理意见为"否决"：工单状态变为 `rejected`
* 其他处理意见：工单状态变为 `processing`

这种关系通过状态机在模型层实现，而不是通过数据库约束。

## 8. 工单与费用明细状态联动

工单状态会影响关联的费用明细状态：

* 工单状态为 `approved`：费用明细状态变为 `verified`
* 其他任何工单状态：费用明细状态变为 `problematic`

当报销单下所有费用明细状态都为 `verified` 时，报销单状态自动变为 `waiting_completion`。

## 9. 沟通工单的需要沟通标志

`needs_communication` 实现为布尔字段（boolean），而不是状态值。这样设计允许沟通工单在任何状态下都可以标记为"需要沟通"，更灵活地满足业务需求。

* 沟通工单可以在 `pending`、`processing`、`approved` 或 `rejected` 任何状态下设置 `needs_communication = true`
* 此标志不影响工单的主状态流转
* 在界面上可以通过复选框或开关控制此标志

## 10. 费用明细状态简化

根据[费用明细状态简化](10_simplify_fee_detail_status.md)文档的建议，我们已经简化了费用明细状态的设计：

* 移除了`fee_detail_selections`表中的`verification_status`字段
* 只保留`fee_details`表中的`verification_status`字段作为费用明细的唯一状态
* 工单状态变更时，直接更新关联费用明细的`verification_status`
* 这种简化使系统更加清晰和易于维护

相关的数据库迁移已经实现：`db/migrate/20250501051827_remove_verification_status_from_fee_detail_selections.rb`