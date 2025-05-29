# SCI2 工单系统数据库结构调整

本文档描述了SCI2工单系统数据库结构调整的实现方案，包括迁移脚本、模型更新和服务层实现。

## 1. 数据库结构变更概述

根据开发计划，我们对数据库结构进行了以下调整：

1. **简化问题代码库结构**：
   - 将原有的多层级结构简化为 `FeeType` -> `ProblemType` 两层结构
   - 移除了不必要的中间表和关联表

2. **优化字段设计**：
   - 为 `FeeType` 添加 `code`, `title`, `meeting_type`, `active` 字段
   - 为 `ProblemType` 添加 `code`, `title`, `sop_description`, `standard_handling` 字段
   - 建立 `ProblemType` 与 `FeeType` 的直接关联

3. **移除冗余表**：
   - 移除 `problem_type_fee_types` 关联表
   - 移除 `problem_descriptions` 表
   - 移除 `materials` 和 `problem_type_materials` 表
   - 移除 `document_categories` 表

## 2. 迁移脚本说明

我们创建了以下迁移脚本来实现数据库结构调整：

1. `20250529100000_update_fee_types_table.rb`：更新 `fee_types` 表结构
2. `20250529100001_update_problem_types_table.rb`：更新 `problem_types` 表结构
3. `20250529100002_remove_document_category_from_problem_types.rb`：移除 `document_category_id` 字段
4. `20250529100003_remove_problem_type_fee_types_table.rb`：移除 `problem_type_fee_types` 表
5. `20250529100004_remove_problem_descriptions_table.rb`：移除 `problem_descriptions` 表
6. `20250529100005_remove_materials_related_tables.rb`：移除 `materials` 相关表
7. `20250529100006_remove_document_categories_table.rb`：移除 `document_categories` 表
8. `20250529100007_migrate_problem_code_data.rb`：数据迁移脚本

## 3. 模型更新

我们更新了以下模型以适应新的数据库结构：

1. `FeeType`：添加新字段和关联
2. `ProblemType`：添加新字段和关联
3. `WorkOrder`：更新关联和方法
4. `FeeDetail`：更新关联和方法
5. `Reimbursement`：更新关联和方法

## 4. 服务层实现

我们创建了以下服务类来支持新的业务逻辑：

1. `ProblemCodeMigrationService`：负责将旧结构数据迁移到新结构
2. `ProblemCodeImportService`：负责从CSV文件导入问题代码
3. `FeeDetailStatusService`：实现"最新工单决定原则"
4. `WorkOrderProblemService`：处理工单中的问题添加和格式化

## 5. 执行迁移步骤

按照以下步骤执行数据库迁移：

1. **备份数据库**：
   ```bash
   rails db:dump
   ```

2. **运行迁移脚本**：
   ```bash
   rails db:migrate
   ```

3. **导入问题代码**：
   ```bash
   rails problem_codes:import
   ```

4. **验证数据完整性**：
   ```bash
   rails problem_codes:validate
   ```

## 6. 注意事项

1. **数据备份**：执行迁移前务必备份数据库，以防数据丢失。
2. **迁移顺序**：迁移脚本必须按照编号顺序执行，不可跳过。
3. **数据验证**：迁移后应验证数据完整性，确保所有数据正确迁移。
4. **问题代码导入**：如果有新的问题代码CSV文件，可以使用 `rails problem_codes:import` 导入。

## 7. 回滚方案

如需回滚迁移，可执行以下命令：

```bash
rails db:rollback STEP=8
```

注意：回滚会丢失在新结构中创建的数据，请谨慎操作。

## 8. 后续工作

完成数据库结构调整后，需要进行以下工作：

1. 更新控制器和视图以适应新的数据结构
2. 实现两级级联下拉选择组件
3. 实现多问题添加功能
4. 更新测试用例以覆盖新的功能