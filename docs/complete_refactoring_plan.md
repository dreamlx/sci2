# SCI2 工单系统完全重构计划

## 1. 概述

根据对当前系统的分析和评估，我们决定进行完全重构，抛弃现有代码，从零开始实现新的设计。这种方法将允许我们摆脱现有架构的限制，实现更清晰、更高效的系统设计。

本文档提供了完全重构的详细计划，包括新的数据库结构、模型实现、控制器和视图设计、测试策略以及实施时间表。

## 2. 核心设计原则

1. **独立拆表**：为每种工单类型创建独立的表，避免STI带来的性能和维护问题
2. **清晰的关联关系**：使用直接的外键关联替代多态关联，简化查询和提高性能
3. **状态机分离**：为每种工单类型实现独立的状态机，使状态流转更加清晰
4. **服务对象模式**：使用服务对象封装复杂的业务逻辑，保持模型的简洁
5. **测试驱动开发**：采用TDD方法，确保代码质量和功能正确性

## 3. 数据库结构设计

### 3.1 工单表设计

我们将为每种工单类型创建独立的表，替代原来的单表继承设计：

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

### 3.2 关联表设计

#### 费用明细选择表 (fee_detail_selections)

```
id: integer (PK)
fee_detail_id: integer (FK)
audit_work_order_id: integer (FK, 可为null)
communication_work_order_id: integer (FK, 可为null)
verification_status: string [pending, verified, rejected]
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

## 4. 模型实现计划

### 4.1 工单模型

#### 快递收单工单模型 (ExpressReceiptWorkOrder)

```ruby
class ExpressReceiptWorkOrder < ApplicationRecord
  # 关联
  belongs_to :reimbursement
  has_one :audit_work_order
  
  # 状态机
  state_machine :status, initial: :received do
    event :process do
      transition received: :processed
    end
    
    event :complete do
      transition processed: :completed
    end
    
    after_transition to: :completed do |work_order, _|
      work_order.after_complete
    end
  end
  
  # 回调方法
  def after_complete
    # 创建审核工单
    AuditWorkOrder.create!(
      reimbursement: reimbursement,
      express_receipt_work_order: self,
      status: 'pending',
      created_by: created_by
    )
  end
end
```

#### 审核工单模型 (AuditWorkOrder)

```ruby
class AuditWorkOrder < ApplicationRecord
  # 关联
  belongs_to :reimbursement
  belongs_to :express_receipt_work_order, optional: true
  has_many :communication_work_orders
  has_many :fee_detail_selections
  has_many :fee_details, through: :fee_detail_selections
  
  # 状态机
  state_machine :status, initial: :pending do
    event :start_processing do
      transition pending: :processing
    end
    
    event :start_audit do
      transition processing: :auditing
    end
    
    event :approve do
      transition auditing: :approved
    end
    
    event :reject do
      transition auditing: :rejected
    end
    
    event :need_communication do
      transition auditing: :needs_communication
    end
    
    event :resume_audit do
      transition needs_communication: :auditing
    end
    
    event :complete do
      transition [:approved, :rejected] => :completed
    end
  end
  
  # 方法
  def create_communication_work_order(params = {})
    # 创建沟通工单
    comm_order = CommunicationWorkOrder.create!(
      reimbursement: reimbursement,
      audit_work_order: self,
      status: 'open',
      created_by: created_by,
      **params
    )
    
    # 更新自身状态
    need_communication! unless status == 'needs_communication'
    
    comm_order
  end
end
```

#### 沟通工单模型 (CommunicationWorkOrder)

```ruby
class CommunicationWorkOrder < ApplicationRecord
  # 关联
  belongs_to :reimbursement
  belongs_to :audit_work_order
  has_many :communication_records
  has_many :fee_detail_selections
  has_many :fee_details, through: :fee_detail_selections
  
  # 状态机
  state_machine :status, initial: :open do
    event :start_communication do
      transition open: :in_progress
    end
    
    event :resolve do
      transition in_progress: :resolved
    end
    
    event :mark_unresolved do
      transition in_progress: :unresolved
    end
    
    event :close do
      transition [:resolved, :unresolved] => :closed
    end
    
    after_transition to: :resolved do |work_order, _|
      work_order.after_resolve
    end
  end
  
  # 方法
  def add_communication_record(params)
    communication_records.create!(
      recorded_at: Time.current,
      **params
    )
  end
  
  def after_resolve
    # 通知审核工单
    if audit_work_order.present? && audit_work_order.status == 'needs_communication'
      audit_work_order.resume_audit
    end
  end
end
```

## 5. 服务对象实现计划

### 5.1 数据导入服务

我们将创建专门的服务对象来处理数据导入，确保导入逻辑与模型分离：

1. **ReimbursementImportService**: 处理报销单导入
2. **ExpressReceiptImportService**: 处理快递收单导入
3. **FeeDetailImportService**: 处理费用明细导入
4. **OperationHistoryImportService**: 处理操作历史导入

### 5.2 工单处理服务

1. **AuditWorkOrderService**: 处理审核工单的业务逻辑
2. **CommunicationWorkOrderService**: 处理沟通工单的业务逻辑
3. **FeeDetailVerificationService**: 处理费用明细验证的业务逻辑

## 6. 控制器和视图设计

### 6.1 ActiveAdmin资源

我们将为每种工单类型创建独立的ActiveAdmin资源：

1. **ExpressReceiptWorkOrdersAdmin**: 快递收单工单管理
2. **AuditWorkOrdersAdmin**: 审核工单管理
3. **CommunicationWorkOrdersAdmin**: 沟通工单管理

### 6.2 自定义视图

为每种工单类型创建专门的视图，以展示其特定信息和操作：

1. **快递收单工单视图**: 显示快递信息和状态转换按钮
2. **审核工单视图**: 显示审核信息、费用明细选择和状态转换按钮
3. **沟通工单视图**: 显示沟通记录、问题描述和状态转换按钮

## 7. 测试策略

### 7.1 单元测试

为每个模型和服务对象编写单元测试，确保其功能正确性：

1. **模型测试**: 测试验证、关联和方法
2. **状态机测试**: 测试状态转换和回调
3. **服务对象测试**: 测试业务逻辑和边界条件

### 7.2 集成测试

编写集成测试，测试多个组件之间的交互：

1. **数据导入测试**: 测试导入流程和数据一致性
2. **工单流程测试**: 测试完整的工单处理流程
3. **费用明细验证测试**: 测试费用明细选择和验证流程

## 8. 实施时间表

### 8.1 阶段一：基础设计与准备（1周）

- 完善数据库设计
- 创建数据库迁移脚本
- 设计模型关联关系
- 准备测试环境和测试数据

### 8.2 阶段二：核心模型实现（2周）

- 实现基础工单功能
- 实现各类工单模型
- 实现工单状态流转逻辑
- 实现工单关联关系

### 8.3 阶段三：业务逻辑与服务（2周）

- 实现数据导入服务
- 实现工单创建和处理服务
- 实现费用明细验证逻辑
- 实现状态变更记录逻辑

### 8.4 阶段四：界面与交互（2周）

- 实现ActiveAdmin资源
- 实现工单列表和详情页
- 实现状态转换操作
- 实现费用明细选择界面

### 8.5 阶段五：测试与优化（2周）

- 执行单元测试和集成测试
- 性能测试和优化
- 用户验收测试
- 部署准备

## 9. 总结

通过这次完全重构，我们将实现一个更清晰、更高效的工单系统。独立拆表的设计将解决当前STI设计中的性能和维护问题，直接的外键关联将简化查询和提高性能，独立的状态机将使状态流转更加清晰。

这个重构计划提供了一个全面的路线图，从数据库设计到最终部署，确保项目能够按时、高质量地完成。