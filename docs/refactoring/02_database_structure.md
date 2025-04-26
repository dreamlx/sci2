# SCI2 工单系统数据库结构设计

## 1. 表结构设计

### 1.1 工单表设计

我们将为每种工单类型创建独立的表，替代原来的单表设计：

#### 快递收单工单表 (express_receipt_work_orders)

```
id: integer (PK)
reimbursement_id: integer (FK)
status: string [received, processed, completed]
tracking_number: string
received_at: datetime
courier_name: string
created_by: integer
created_at: datetime
updated_at: datetime
```

#### 审核工单表 (audit_work_orders)

```
id: integer (PK)
reimbursement_id: integer (FK)
express_receipt_work_order_id: integer (FK, 可为null)
status: string [pending, processing, auditing, approved, rejected, needs_communication, completed]
audit_result: string
audit_comment: text
audit_date: datetime
vat_verified: boolean
created_by: integer
created_at: datetime
updated_at: datetime
```

#### 沟通工单表 (communication_work_orders)

```
id: integer (PK)
reimbursement_id: integer (FK)
audit_work_order_id: integer (FK)
status: string [open, in_progress, resolved, unresolved, closed]
communication_method: string
initiator_role: string
resolution_summary: text
created_by: integer
created_at: datetime
updated_at: datetime
```

### 1.2 关联表设计

#### 费用明细选择表 (fee_detail_selections)

```
id: integer (PK)
fee_detail_id: integer (FK)
audit_work_order_id: integer (FK, 可为null)
communication_work_order_id: integer (FK, 可为null)
verification_status: string [pending, verified, rejected, problematic]
verification_comment: text
verified_by: integer
verified_at: datetime
created_at: datetime
updated_at: datetime
```

#### 沟通记录表 (communication_records)

```
id: integer (PK)
communication_work_order_id: integer (FK)
content: text
communicator_role: string
communicator_name: string
communication_method: string
recorded_at: datetime
created_at: datetime
updated_at: datetime
```

#### 工单状态变更表 (work_order_status_changes)

```
id: integer (PK)
work_order_type: string [express_receipt, audit, communication]
work_order_id: integer
from_status: string
to_status: string
changed_at: datetime
changed_by: integer
created_at: datetime
updated_at: datetime
```

## 2. 数据库迁移计划

### 2.1 创建新表

我们将创建以下迁移脚本来建立新的表结构：

```ruby
# 创建快递收单工单表
class CreateExpressReceiptWorkOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :express_receipt_work_orders do |t|
      t.references :reimbursement, foreign_key: true
      t.string :status, null: false
      t.string :tracking_number
      t.datetime :received_at
      t.string :courier_name
      t.integer :created_by
      
      t.timestamps
    end
    
    add_index :express_receipt_work_orders, :status
  end
end

# 创建审核工单表
class CreateAuditWorkOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :audit_work_orders do |t|
      t.references :reimbursement, foreign_key: true
      t.references :express_receipt_work_order, foreign_key: true, null: true
      t.string :status, null: false
      t.string :audit_result
      t.text :audit_comment
      t.datetime :audit_date
      t.boolean :vat_verified
      t.integer :created_by
      
      t.timestamps
    end
    
    add_index :audit_work_orders, :status
  end
end

# 创建沟通工单表
class CreateCommunicationWorkOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :communication_work_orders do |t|
      t.references :reimbursement, foreign_key: true
      t.references :audit_work_order, foreign_key: true
      t.string :status, null: false
      t.string :communication_method
      t.string :initiator_role
      t.text :resolution_summary
      t.integer :created_by
      
      t.timestamps
    end
    
    add_index :communication_work_orders, :status
  end
end

# 修改费用明细选择表
class UpdateFeeDetailSelections < ActiveRecord::Migration[7.0]
  def change
    remove_column :fee_detail_selections, :selectable_id, :integer
    remove_column :fee_detail_selections, :selectable_type, :string
    
    add_reference :fee_detail_selections, :audit_work_order, foreign_key: true, null: true
    add_reference :fee_detail_selections, :communication_work_order, foreign_key: true, null: true
    
    add_index :fee_detail_selections, [:fee_detail_id, :audit_work_order_id], unique: true, name: 'index_fee_detail_selections_on_fee_detail_and_audit_work_order'
    add_index :fee_detail_selections, [:fee_detail_id, :communication_work_order_id], unique: true, name: 'index_fee_detail_selections_on_fee_detail_and_comm_work_order'
  end
end

# 修改沟通记录表
class UpdateCommunicationRecords < ActiveRecord::Migration[7.0]
  def change
    remove_column :communication_records, :work_order_id, :integer
    add_reference :communication_records, :communication_work_order, foreign_key: true
  end
end

# 创建工单状态变更表
class CreateWorkOrderStatusChanges < ActiveRecord::Migration[7.0]
  def change
    create_table :work_order_status_changes do |t|
      t.string :work_order_type, null: false
      t.integer :work_order_id, null: false
      t.string :from_status
      t.string :to_status, null: false
      t.datetime :changed_at, null: false
      t.integer :changed_by
      
      t.timestamps
    end
    
    add_index :work_order_status_changes, [:work_order_type, :work_order_id]
    add_index :work_order_status_changes, :changed_at
  end
end
```

### 2.2 数据迁移策略

由于是全新重构，我们可以采用以下迁移策略：

1. **创建新表结构**：
   - 创建所有新的表结构
   - 设置适当的索引和约束

2. **数据导入流程**：
   - 实现新的数据导入服务
   - 按照报销单 -> 快递收单 -> 费用明细 -> 操作历史的顺序导入数据
   - 在导入过程中创建相应的工单记录

3. **不迁移旧数据**：
   - 考虑到是全新重构，可以不迁移旧系统的数据
   - 如果需要历史数据，可以考虑只读方式访问旧系统

## 3. 索引优化

为了提高查询性能，我们将添加以下索引：

1. **工单表索引**：
   - 对状态字段添加索引，便于按状态筛选工单
   - 对外键字段添加索引，提高关联查询性能

2. **费用明细选择表索引**：
   - 对费用明细ID和工单ID的组合添加唯一索引，确保一个费用明细在一个工单中只被选择一次

3. **工单状态变更表索引**：
   - 对工单类型和ID的组合添加索引，便于查询特定工单的状态变更历史
   - 对变更时间添加索引，便于按时间顺序查询状态变更

## 4. 数据库约束

为了确保数据一致性，我们将添加以下约束：

1. **外键约束**：
   - 确保工单关联到有效的报销单
   - 确保沟通工单关联到有效的审核工单
   - 确保费用明细选择关联到有效的费用明细和工单

2. **非空约束**：
   - 确保工单状态字段不为空
   - 确保必要的关联字段不为空

3. **唯一约束**：
   - 确保费用明细在一个工单中只被选择一次

## 5. 数据库设计考虑因素

### 5.1 性能考虑

1. **表拆分**：
   - 通过将不同类型的工单拆分到独立的表中，避免单表过大导致的性能问题
   - 每个表只包含与该类型工单相关的字段，减少表的宽度

2. **索引策略**：
   - 为常用查询条件添加索引
   - 为外键字段添加索引
   - 避免过多索引导致写入性能下降

### 5.2 扩展性考虑

1. **新工单类型**：
   - 如果将来需要添加新的工单类型，只需创建新的表
   - 不会影响现有表结构和查询

2. **新字段**：
   - 可以轻松地为特定类型的工单添加新字段
   - 不会影响其他类型的工单

### 5.3 ActiveAdmin兼容性

1. **直接映射**：
   - 每个表可以直接映射到一个ActiveAdmin资源
   - 避免STI在ActiveAdmin中可能导致的复杂性

2. **关联展示**：
   - 可以在ActiveAdmin中轻松展示工单之间的关联关系
   - 可以使用has_many和belongs_to关联简化表单和显示