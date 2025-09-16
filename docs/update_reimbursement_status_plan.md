# 报销单导入状态映射文档

## 概述

本文档详细说明了报销单导入过程中的状态映射逻辑，包括外部状态到内部状态的转换规则、手动覆盖功能、以及批量更新机制。

## 状态映射流程图

```mermaid
flowchart LR
  A[导入流程开始] --> B[按行读取 CSV/表格]
  B --> C[查找或初始化 Reimbursement]
  C --> D{manual_override?}
  D -->|是| E[跳过状态变更<br/>直接保存其他字段]
  D -->|否| F{external_status 匹配 /已付款\|待付款/ ?}
  F -->|是| G[内部状态 = STATUS_CLOSED]
  F -->|否| H{has_active_work_orders?}
  H -->|是| I[内部状态 = STATUS_PROCESSING]
  H -->|否| J[内部状态 = STATUS_PENDING]
  E & G & I & J --> K[保存 Reimbursement 并更新 last_external_status]
  K --> L[继续批量/单条导入]
```

## 状态映射规则

### 外部状态到内部状态的映射
- **已付款** 或 **待付款** → `STATUS_CLOSED`
- 其他外部状态 + 存在活跃工单 → `STATUS_PROCESSING`
- 其他外部状态 + 无活跃工单 → `STATUS_PENDING`

### 手动覆盖保护
当报销单的 `manual_override` 字段为 `true` 时，系统会跳过所有状态变更逻辑，只更新其他字段和 `last_external_status`。这允许管理员手动设置特定报销单的状态而不被自动流程覆盖。

## 实现详情

### 1. 模型层状态计算
在 [`app/models/reimbursement.rb`](app/models/reimbursement.rb:331) 中实现了 `determine_internal_status_from_external` 方法：

```ruby
def determine_internal_status_from_external(external_status_value)
  return status if manual_override?
  if external_status_value&.match?(/已付款|待付款/)
    return STATUS_CLOSED
  end
  if has_active_work_orders?
    return STATUS_PROCESSING
  end
  STATUS_PENDING
end
```

### 2. 批量导入服务优化
在 [`app/services/optimized_reimbursement_import_service.rb`](app/services/optimized_reimbursement_import_service.rb:191) 中优化了 `batch_update_statuses` 方法，使用批量查询和更新来提高性能。

### 3. 状态回补任务
创建了 [`lib/tasks/update_reimbursement_statuses.rake`](lib/tasks/update_reimbursement_statuses.rake:1) Rake 任务，用于对已导入的数据执行状态回补：

```bash
# 执行状态回补
rails reimbursements:update_statuses
```

**优化特性**：
- 批量处理：每批处理50条记录，避免长时间事务锁定
- 错误重试：自动重试机制，处理数据库锁定问题
- 指数退避：重试时使用递增延迟，减少锁竞争
- 进度跟踪：实时显示处理进度和更新详情

## 测试覆盖

### 单元测试
- [`spec/services/reimbursement_import_service_spec.rb`](spec/services/reimbursement_import_service_spec.rb:146) - 测试状态映射逻辑
- [`spec/services/optimized_reimbursement_import_service_spec.rb`](spec/services/optimized_reimbursement_import_service_spec.rb:1) - 测试批量更新功能

### 测试场景覆盖
- 已付款/待付款状态正确映射到 closed
- 手动覆盖功能正常工作
- 存在活跃工单时状态为 processing
- 无活跃工单时状态为 pending

## 使用指南

### 导入数据
1. 准备 CSV 文件包含 `external_status` 字段
2. 使用 ActiveAdmin 导入界面或直接调用导入服务
3. 系统会自动根据外部状态更新内部状态

### 手动覆盖
如果需要防止特定报销单的状态被自动更新：
```ruby
reimbursement.update!(manual_override: true)
```

### 状态回补
对于已导入的数据，可以运行 Rake 任务重新计算状态：
```bash
rails reimbursement_statuses:update
```

## 相关文件
- [`app/models/reimbursement.rb`](app/models/reimbursement.rb:331) - 状态计算逻辑
- [`app/services/optimized_reimbursement_import_service.rb`](app/services/optimized_reimbursement_import_service.rb:191) - 批量导入服务
- [`lib/tasks/update_reimbursement_statuses.rake`](lib/tasks/update_reimbursement_statuses.rake:1) - 状态回补任务
- 相关测试文件

## 版本历史
- **2025-09-15** - 实现外部状态到内部状态的自动映射功能
- **2025-09-15** - 添加手动覆盖保护机制
- **2025-09-15** - 优化批量导入性能
