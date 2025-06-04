# SCI2 工单系统数据库迁移指南

本文档提供了执行SCI2工单系统数据库结构调整的详细步骤和注意事项。

## 1. 迁移概述

我们已经创建了以下文件来实现数据库结构调整：

### 1.1 数据库迁移脚本

1. `db/migrate/20250529100000_update_fee_types_table.rb` - 创建或更新 `fee_types` 表结构
2. `db/migrate/20250529100001_update_problem_types_table.rb` - 创建或更新 `problem_types` 表结构
3. `db/migrate/20250529100002_remove_document_category_from_problem_types.rb` - 移除 `document_category_id` 字段（如果存在）
4. `db/migrate/20250529100003_remove_problem_type_fee_types_table.rb` - 移除 `problem_type_fee_types` 表（如果存在）
5. `db/migrate/20250529100004_remove_problem_descriptions_table.rb` - 移除 `problem_descriptions` 表（如果存在）
6. `db/migrate/20250529100005_remove_materials_related_tables.rb` - 移除 `materials` 相关表（如果存在）
7. `db/migrate/20250529100006_remove_document_categories_table.rb` - 移除 `document_categories` 表（如果存在）
8. `db/migrate/20250529100007_migrate_problem_code_data.rb` - 数据迁移脚本

所有迁移脚本都已经更新，以处理表或列不存在的情况，确保迁移可以在新环境中顺利执行。

### 1.2 模型更新

1. `app/models/fee_type.rb` - 更新 `FeeType` 模型
2. `app/models/problem_type.rb` - 更新 `ProblemType` 模型
3. `app/models/work_order.rb` - 更新 `WorkOrder` 模型，添加状态机配置
4. `app/models/reimbursement.rb` - 更新 `Reimbursement` 模型，添加状态机配置

### 1.3 服务层实现

1. `app/services/problem_code_migration_service.rb` - 问题代码迁移服务
2. `app/services/problem_code_import_service.rb` - 问题代码导入服务
3. `app/services/fee_detail_status_service.rb` - 费用明细状态服务
4. `app/services/work_order_problem_service.rb` - 工单问题服务

### 1.4 测试文件

1. `spec/models/fee_type_problem_type_spec.rb` - `FeeType` 和 `ProblemType` 模型测试
2. `spec/services/work_order_problem_service_spec.rb` - 工单问题服务测试
3. `spec/services/fee_detail_status_service_spec.rb` - 费用明细状态服务测试
4. `spec/services/problem_code_import_service_spec.rb` - 问题代码导入服务测试

## 2. 迁移前准备

### 2.1 备份数据库

在执行迁移前，务必备份数据库以防数据丢失：

```bash
# SQLite 数据库备份
cp db/sci2_development.sqlite3 db/sci2_development.sqlite3.bak

# 或者使用 Rails 任务导出数据
rails db:dump
```

### 2.2 检查依赖关系

确保所有迁移脚本的依赖关系正确，特别是涉及外键的表结构变更。

### 2.3 状态机配置

我们已经更新了 `Reimbursement` 和 `WorkOrder` 模型，添加了状态机配置：

```ruby
# app/models/reimbursement.rb
state_machine :status, initial: :pending do
  event :start_processing do
    transition pending: :processing
  end
  
  event :close_processing do
    transition processing: :closed
  end
  
  event :reopen_to_processing do
    transition closed: :processing
  end
end

# app/models/work_order.rb
state_machine :status, initial: :pending do
  event :approve do
    transition [:pending, :rejected] => :approved
  end
  
  event :reject do
    transition [:pending, :approved] => :rejected
  end
  
  event :complete do
    transition [:pending, :approved, :rejected] => :completed
  end
  
  event :reopen do
    transition :completed => :pending
  end
end
```

这些配置是必要的，因为 ActiveAdmin 配置中使用了 `state_machines` 方法。

## 3. 执行迁移步骤

### 3.1 运行迁移脚本

```bash
# 运行所有待执行的迁移
bundle exec rails db:migrate

# 或者指定运行特定迁移
bundle exec rails db:migrate VERSION=20250529100007
```

### 3.2 导入问题代码

```bash
# 导入问题代码
bundle exec rails problem_codes:import

# 如果需要重置问题代码
bundle exec rails problem_codes:reset
```

### 3.3 运行测试

```bash
# 运行所有测试
bundle exec rspec

# 运行特定测试
bundle exec rspec spec/models/fee_type_problem_type_spec.rb
bundle exec rspec spec/services/work_order_problem_service_spec.rb
bundle exec rspec spec/services/fee_detail_status_service_spec.rb
bundle exec rspec spec/services/problem_code_import_service_spec.rb
```

**注意：** 使用 `bundle exec` 前缀可以确保使用 Gemfile 中指定的 gem 版本，避免版本冲突问题。

## 4. 迁移后验证

### 4.1 数据验证

1. 检查 `fee_types` 表是否包含正确的字段和数据
2. 检查 `problem_types` 表是否包含正确的字段和数据
3. 验证 `fee_types` 和 `problem_types` 之间的关联关系
4. 确认不再使用的表已被正确移除

### 4.2 功能验证

1. 测试问题代码导入功能
2. 测试工单问题添加功能
3. 测试费用明细状态更新功能
4. 测试"最新工单决定原则"是否正确实现

## 5. 回滚方案

如果迁移过程中出现问题，可以使用以下命令回滚迁移：

```bash
# 回滚最近的迁移
bundle exec rails db:rollback

# 回滚多个迁移
bundle exec rails db:rollback STEP=8

# 回滚到特定版本
bundle exec rails db:migrate VERSION=20250506085214
```

回滚后，恢复之前备份的数据库：

```bash
# 恢复 SQLite 数据库备份
cp db/sci2_development.sqlite3.bak db/sci2_development.sqlite3

# 或者使用 Rails 任务导入数据
bundle exec rails db:restore
```

## 6. 注意事项

1. 迁移过程中可能会暂时影响系统功能，建议在非业务高峰期执行
2. 迁移完成后，需要更新相关的控制器和视图代码以适应新的数据结构
3. 如果使用了缓存，需要清除缓存以避免数据不一致
4. 确保所有团队成员了解数据结构变更，并更新相关文档
5. 如果遇到 `undefined method 'state_machines'` 错误，请确保已经在相应的模型中添加了状态机配置
6. 所有迁移脚本都已经更新，以处理表或列不存在的情况，确保迁移可以在新环境中顺利执行
7. 如果遇到 gem 版本冲突问题，请使用 `bundle exec` 前缀运行命令，确保使用 Gemfile 中指定的 gem 版本

## 7. 后续工作

完成数据库结构调整后，需要进行以下工作：

1. 实现两级级联下拉选择组件
2. 实现多问题添加功能
3. 更新工单创建和编辑界面
4. 更新费用明细状态显示逻辑
5. 更新报销单状态管理逻辑