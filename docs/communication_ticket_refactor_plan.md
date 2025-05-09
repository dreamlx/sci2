# CommunicationTicket 重构计划：对齐 AuditTicket

**目标：** 使 `CommunicationWorkOrder` 的行为和界面与 `AuditWorkOrder` 完全一致，移除其多轮沟通特性。

---

## I. 模型层 (`app/models/`)

### 1. `CommunicationWorkOrder` (`communication_work_order.rb`)

*   **移除关联和方法：**
    *   删除 `has_many :communication_records, ...`
    *   删除 `add_communication_record` 方法。
    *   删除 `needs_communication?`, `mark_needs_communication!`, `unmark_needs_communication!` 方法。
    *   删除 `scope :needs_communication`。
*   **移除/替换字段 (可能需要数据库迁移)：**
    *   删除 `needs_communication` 字段。 (DB migration)
    *   删除 `communication_method` 字段。 (DB migration)
    *   删除 `initiator_role` 字段。 (DB migration)
    *   **字段统一/映射：**
        *   将 `resolution_summary` 的用途对齐 `AuditWorkOrder` 的 `audit_comment`。
            *   推荐: 在 `communication_work_orders` 表中添加 `audit_comment` 字段 (如果尚不存在于 `work_orders` 表)，并将现有的 `resolution_summary` 数据迁移到 `audit_comment`。然后代码中统一使用 `audit_comment`。移除 `resolution_summary` 字段。
*   **添加字段 (如果需要且不存在于父表 `work_orders`)：**
    *   确保 `CommunicationWorkOrder` 实例能响应 `audit_result` 和 `audit_date`。这些字段应存在于 `work_orders` 表。
*   **状态机调整 (与 `AuditWorkOrder` 对齐)：**
    *   检查 `CommunicationWorkOrder` 的状态机回调。确保在 `approve` 和 `reject` 事件的 `before_transition` 或 `after_transition` 中，能正确设置 `audit_result` 和 `audit_date`，就像 `AuditWorkOrder` 那样（`AuditWorkOrder` 在 `before_transition` 中设置）。
*   **费用明细处理：**
    *   移除 `CommunicationWorkOrder` 中的 `select_fee_detail`, `select_fee_details`, `process_fee_detail_selections` 方法。依赖父类 `WorkOrder` 的 `fee_detail_ids` accessor 和 `process_fee_detail_ids`回调。
*   **Ransackable Attributes/Associations:**
    *   从 `subclass_ransackable_attributes` 移除沟通特有字段 (`communication_method`, `initiator_role`, `needs_communication`，以及 `resolution_summary` 如果被替换)。
    *   加入 `audit_result`, `audit_comment` (如果使用这个名字), `audit_date` (如果它们之前不在此处)。
    *   从 `subclass_ransackable_associations` 移除 `communication_records`。

### 2. `WorkOrder` (`work_order.rb`)

*   **`set_status_based_on_processing_opinion` 方法调整：**
    *   优先让子类状态机（`CommunicationWorkOrder` 和 `AuditWorkOrder`）在各自的 `approve`/`reject` 回调中处理 `audit_result` 和 `audit_date` 的设置，以保持一致性。父类此方法中针对 `AuditWorkOrder` 设置这些字段的逻辑可以移除或调整为后备（如果子类状态机未处理）。
*   **费用明细处理 (确认)：**
    *   确认 `fee_detail_ids` accessor 和 `process_fee_detail_ids` 回调能够通用地为所有子类工作。

### 3. 数据库迁移 (`db/migrate/`)

*   创建一个新的迁移文件：
    *   从 `work_orders` 表移除 `needs_communication` (boolean), `communication_method` (string), `initiator_role` (string) 列。
    *   **处理 `resolution_summary` 和 `audit_comment`:**
        *   如果在 `work_orders` 表尚不存在 `audit_comment` (text 或 string)，则添加。
        *   数据迁移：将 `CommunicationWorkOrder` 的 `resolution_summary` 值迁移到 `audit_comment`。
        *   从 `work_orders` 表移除 `resolution_summary` (string) 列。
    *   确保 `audit_result` (string) 和 `audit_date` (datetime) 列存在于 `work_orders` 表。

---

## II. 服务层 (`app/services/`)

### 1. `CommunicationWorkOrderService` (`communication_work_order_service.rb`)

*   **移除/重构方法：**
    *   移除 `toggle_needs_communication`。
    *   移除 `add_communication_record`。
    *   检查 `start_processing`, `approve`, `reject` 方法：
        *   移除与 `needs_communication` 或 `communication_records` 相关的逻辑。
        *   确保它们在参数和行为上与 `AuditWorkOrderService` 中的对应方法一致。特别是 `approve` 和 `reject` 方法，它们现在需要处理 `audit_comment` (或映射后的字段) 和 `processing_opinion`，并触发能设置 `audit_result` 和 `audit_date` 的状态转换。
*   **考虑合并/废弃：**
    *   短期内，先修改 `CommunicationWorkOrderService` 使其行为对齐。长期来看，如果与 `AuditWorkOrderService` 高度相似，考虑合并或创建通用服务。

### 2. `AuditWorkOrderService` (`audit_work_order_service.rb`)

*   暂时无需大改。

---

## III. 控制器/视图层 (ActiveAdmin - `app/admin/`)

### 1. `communication_work_orders.rb`

*   **`permit_params` 修改：**
    *   移除 `:communication_method`, `:initiator_role`, `:resolution_summary` (如果被替换), `:needs_communication`。
    *   确保 `processing_opinion` 和 `:audit_comment` (或等效的评论字段，如 `:remark` 如果通用) 在 `permit_params` 中，用于 `approve/reject` 表单提交。`audit_result` 和 `audit_date` 通常由系统设置。
*   **Controller `create` 和 `update` 方法：**
    *   确保它们不再引用已移除的参数。
    *   **费用明细处理：** 移除控制器中手动创建 `FeeDetailSelection` 的逻辑。依赖模型回调。
*   **过滤器 (`filter`) 修改：**
    *   移除对 `communication_method`, `initiator_role`, `needs_communication` 的过滤。
    *   添加对 `audit_result` 的过滤 (如果适用)。
*   **范围 (`scope`) 修改：**
    *   移除 `scope :needs_communication`。
*   **Action Items 和 Member Actions 修改：**
    *   移除 `member_action :toggle_needs_communication`。
    *   移除 `member_action :new_communication_record` 和 `create_communication_record`。
    *   确保 `start_processing`, `approve`/`do_approve`, `reject`/`do_reject` 的逻辑、视图、按钮条件、以及传递给服务层的参数，与 `audit_work_orders.rb` 中的对应操作完全一致。
        *   `approve`/`reject` 视图 (`app/views/admin/communication_work_orders/approve.html.erb` 和 `reject.html.erb`) 需要修改，确保提交的字段名与 `AuditWorkOrder` 的一致（例如，使用 `f.input :audit_comment`，并包含 `processing_opinion` 等）。
*   **Index Page (`index do ... end`) 修改：**
    *   移除与沟通相关的列。
    *   添加/修改为与审核工单一致的列 (`audit_result`, `audit_comment` 等)。
*   **Show Page (`show do ... end`) 修改：**
    *   移除沟通记录的展示和相关操作。
    *   确保展示的字段和布局与审核工单一致。
*   **Form Page (`form do |f| ... end`) 修改：**
    *   移除沟通相关的输入字段。
    *   确保输入字段与审核工单的表单一致 (主要是 `processing_opinion`, `audit_comment` 等，费用明细选择器)。

### 2. Views (`app/views/admin/communication_work_orders/`)

*   删除与沟通记录相关的视图文件。
*   修改 `approve.html.erb`, `reject.html.erb` 以匹配 `audit_work_orders` 的对应视图。
*   检查 `_form.html.erb` (如果有) 或直接在 `app/admin/communication_work_orders.rb` 中的 `form` DSL。

---

## IV. 测试

*   全面测试 `CommunicationWorkOrder` 的 CRUD 操作。
*   测试其状态转换（pending -> processing -> approved/rejected）是否与 `AuditWorkOrder` 一致。
*   确认 `audit_result` 和 `audit_date` 在 `CommunicationWorkOrder` 上被正确设置。
*   确认费用明细选择和状态更新对 `CommunicationWorkOrder` 正常工作。
*   确认所有与多轮沟通相关的界面元素和功能已移除。
*   回归测试 `AuditWorkOrder` 确保其功能不受影响。

--- 