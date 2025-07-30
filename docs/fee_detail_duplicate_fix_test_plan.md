# 费用明细重复记录修复测试计划

本文档提供了测试费用明细重复记录修复方案的步骤和验证点。

## 测试环境准备

1. 在开发或测试环境中执行测试，**不要**在生产环境中直接测试
2. 在测试前备份数据库
3. 确保测试环境中有足够的测试数据，包括：
   - 具有 `nil` 值的 `external_fee_id` 记录
   - 具有重复 `external_fee_id` 值的记录
   - 正常的唯一 `external_fee_id` 记录

## 测试步骤

### 1. 数据库迁移测试

1. 运行第一个迁移，确保所有记录都有 `external_fee_id` 值：

```bash
rails db:migrate:up VERSION=20250725080400
```

2. 验证所有 `fee_details` 记录都有非空的 `external_fee_id` 值：

```ruby
# 在 Rails 控制台中执行
FeeDetail.where(external_fee_id: nil).count # 应该返回 0
```

3. 运行第二个迁移，修复重复的 `external_fee_id` 值：

```bash
rails db:migrate:up VERSION=20250725080500
```

4. 验证没有重复的 `external_fee_id` 值：

```ruby
# 在 Rails 控制台中执行
duplicates = FeeDetail.select(:external_fee_id).group(:external_fee_id).having("COUNT(*) > 1").count
duplicates.empty? # 应该返回 true
```

### 2. 清理脚本测试

1. 运行清理脚本：

```bash
rails runner db/scripts/fix_duplicate_external_fee_ids.rb
```

2. 验证脚本输出，确认：
   - 所有 `nil` 值已被修复
   - 所有重复值已被修复
   - 没有报告错误

3. 再次验证数据库中没有 `nil` 或重复的 `external_fee_id` 值

### 3. 导入功能测试

1. 准备测试导入文件，包含以下场景：
   - 正常记录（所有字段都有值）
   - 缺少 `external_fee_id` 的记录（应被拒绝）
   - 使用已存在的 `external_fee_id` 但其他字段不同的记录（应更新现有记录）
   - 使用已存在的 `external_fee_id` 但 `document_number` 不同的记录（应更新并记录变更）

2. 使用管理界面或直接调用 `FeeDetailImportService` 导入测试文件

3. 验证导入结果：
   - 缺少 `external_fee_id` 的记录应被拒绝并记录错误
   - 使用已存在 `external_fee_id` 的记录应正确更新
   - 更改 `document_number` 的记录应正确处理并更新相关报销单状态

### 4. 模型验证测试

1. 在 Rails 控制台中测试 `FeeDetail` 模型验证：

```ruby
# 测试创建没有 external_fee_id 的记录（应失败）
fee_detail = FeeDetail.new(document_number: "TEST001", fee_type: "测试", amount: 100)
fee_detail.valid? # 应返回 false
fee_detail.errors.full_messages # 应包含 external_fee_id 不能为空的错误

# 测试创建重复 external_fee_id 的记录（应失败）
existing_id = FeeDetail.first.external_fee_id
fee_detail = FeeDetail.new(document_number: "TEST001", fee_type: "测试", amount: 100, external_fee_id: existing_id)
fee_detail.valid? # 应返回 false
fee_detail.errors.full_messages # 应包含 external_fee_id 已被使用的错误

# 测试创建有效记录（应成功）
fee_detail = FeeDetail.new(document_number: "TEST001", fee_type: "测试", amount: 100, external_fee_id: "TEST-#{SecureRandom.hex(8)}")
fee_detail.valid? # 应返回 true
```

## 验证点

1. 数据完整性：
   - 所有 `fee_details` 记录都应有非空的 `external_fee_id` 值
   - 所有 `external_fee_id` 值都应是唯一的
   - 没有数据丢失或损坏

2. 功能正确性：
   - 导入功能应正确拒绝没有 `external_fee_id` 的记录
   - 导入功能应正确处理重复的 `external_fee_id`
   - 模型验证应正确强制 `external_fee_id` 的存在和唯一性

3. 性能影响：
   - 迁移和脚本的执行时间应在可接受范围内
   - 导入功能的性能不应有明显下降

## 回滚计划

如果测试过程中发现严重问题，请按以下步骤回滚：

1. 恢复之前备份的数据库
2. 如果已经部署了代码更改，回滚相关代码更改

## 生产部署建议

测试成功后，建议按以下步骤在生产环境中部署：

1. 在维护窗口期间执行部署
2. 备份生产数据库
3. 部署代码更改
4. 运行数据库迁移
5. 监控系统日志和性能
6. 验证导入功能正常工作