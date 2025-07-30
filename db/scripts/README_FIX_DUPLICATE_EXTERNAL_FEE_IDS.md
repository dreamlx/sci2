# 修复重复的 external_fee_id 值

本文档提供了如何修复费用明细表中重复的 `external_fee_id` 值的说明。

## 问题背景

在费用明细导入过程中，我们发现了一些重复的 `external_fee_id` 值，这导致了一些报销单对应的费用明细条目出现重复记录问题。为了解决这个问题，我们需要：

1. 修改 `FeeDetailImportService` 以严格要求 `external_fee_id` 存在
2. 更新 `FeeDetail` 模型以强制 `external_fee_id` 的唯一性
3. 清理现有的重复 `external_fee_id` 值

## 解决方案

我们提供了以下解决方案：

1. 两个数据库迁移文件，用于处理现有的 `nil` 和重复的 `external_fee_id` 值
2. 一个 Ruby 脚本，用于识别和清理重复的 `external_fee_id` 值

### 数据库迁移

我们创建了两个迁移文件：

1. `20250725080400_ensure_external_fee_id_presence.rb` - 确保所有记录都有 `external_fee_id` 值
2. `20250725080500_fix_duplicate_external_fee_ids.rb` - 修复重复的 `external_fee_id` 值

运行这些迁移：

```bash
rails db:migrate
```

### 清理脚本

我们还提供了一个脚本，用于识别和清理重复的 `external_fee_id` 值：

```bash
rails runner db/scripts/fix_duplicate_external_fee_ids.rb
```

这个脚本会：

1. 为所有 `external_fee_id` 为 `nil` 的记录生成唯一的 ID
2. 对于每组重复的 `external_fee_id`，保留最近更新的记录，并为其他记录生成新的唯一 ID

## 执行顺序

建议按以下顺序执行：

1. 备份数据库（重要！）
2. 运行数据库迁移
3. 如果迁移过程中出现任何问题，可以运行清理脚本进行更详细的处理

## 注意事项

- 这些操作会修改数据库中的 `external_fee_id` 值，请确保在执行前备份数据库
- 迁移和脚本会保留最近更新的记录，并为其他记录生成新的 ID
- 生成的新 ID 格式为：
  - 对于 `nil` 值：`MIG-{hash}` 或 `GEN-{hash}`
  - 对于重复值：`DEDUP-{original_id}-{record_id}[-{random}]`

## 后续步骤

完成这些操作后，`FeeDetail` 模型将强制要求 `external_fee_id` 存在且唯一，这将防止未来出现重复记录的问题。