# 费用明细重复记录修复方案开发环境测试文档

本文档提供了在开发环境中测试费用明细重复记录修复方案的步骤和结果记录。

## 测试环境

- 环境：开发环境
- 数据库：sci2_development
- 测试时间：2025-07-28

## 测试准备

1. 确保开发环境数据库中包含足够的测试数据
2. 备份当前数据库（可选但推荐）
   ```bash
   rails db:dump:before_fix
   ```

## 测试步骤

### 1. 数据库迁移测试

#### 1.1 运行迁移

```bash
rails db:migrate
```

#### 1.2 验证迁移结果

在 Rails 控制台中执行以下命令，验证迁移是否成功：

```ruby
# 检查 external_fee_id 是否有 NOT NULL 约束
ActiveRecord::Base.connection.columns(:fee_details).find { |c| c.name == 'external_fee_id' }.null
# 应返回 false

# 检查 external_fee_id 是否有唯一索引
ActiveRecord::Base.connection.indexes(:fee_details).any? { |i| i.columns == ['external_fee_id'] && i.unique }
# 应返回 true

# 检查是否存在 nil 值的 external_fee_id
FeeDetail.where(external_fee_id: nil).count
# 应返回 0

# 检查是否存在重复的 external_fee_id
duplicates = FeeDetail.select(:external_fee_id).group(:external_fee_id).having("COUNT(*) > 1").count
duplicates.any?
# 应返回 false
```

### 2. 清理脚本测试

#### 2.1 创建测试数据

在 Rails 控制台中创建一些测试数据：

```ruby
# 临时禁用 external_fee_id 的验证
FeeDetail.skip_callback(:validate, :before, :validate_external_fee_id)

# 创建一些具有相同 external_fee_id 的记录
FeeDetail.create!(
  document_number: "TEST-001",
  fee_type: "测试费用",
  amount: 100,
  fee_date: Date.today,
  external_fee_id: "DUP-TEST-001",
  verification_status: FeeDetail::VERIFICATION_STATUS_PENDING
)

FeeDetail.create!(
  document_number: "TEST-002",
  fee_type: "测试费用",
  amount: 200,
  fee_date: Date.today,
  external_fee_id: "DUP-TEST-001",
  verification_status: FeeDetail::VERIFICATION_STATUS_PENDING
)

# 创建一个没有 external_fee_id 的记录
FeeDetail.create!(
  document_number: "TEST-003",
  fee_type: "测试费用",
  amount: 300,
  fee_date: Date.today,
  external_fee_id: nil,
  verification_status: FeeDetail::VERIFICATION_STATUS_PENDING
)

# 恢复验证
FeeDetail.set_callback(:validate, :before, :validate_external_fee_id)
```

#### 2.2 运行清理脚本

```bash
rails runner db/scripts/fix_duplicate_external_fee_ids.rb
```

#### 2.3 验证清理结果

在 Rails 控制台中执行以下命令，验证清理是否成功：

```ruby
# 检查是否存在 nil 值的 external_fee_id
FeeDetail.where(external_fee_id: nil).count
# 应返回 0

# 检查是否存在重复的 external_fee_id
duplicates = FeeDetail.select(:external_fee_id).group(:external_fee_id).having("COUNT(*) > 1").count
duplicates.any?
# 应返回 false

# 检查测试数据是否被正确处理
FeeDetail.where("external_fee_id LIKE 'DUP-TEST-001%'").count
# 应返回 2

FeeDetail.where("external_fee_id LIKE 'DUP-TEST-001%'").pluck(:external_fee_id)
# 应返回两个不同的 ID，其中一个是原始 ID，另一个是修改后的 ID
```

### 3. 导入功能测试

#### 3.1 准备测试导入文件

创建一个包含以下内容的 CSV 文件 `test_import.csv`：

```
费用id,报销单单号,费用类型,原始金额,费用发生日期,所属月,首次提交日期
IMP-TEST-001,TEST-001,测试费用,100,2025-07-28,7月,2025-07-28
IMP-TEST-002,TEST-002,测试费用,200,2025-07-28,7月,2025-07-28
IMP-TEST-001,TEST-003,测试费用,300,2025-07-28,7月,2025-07-28
,TEST-004,测试费用,400,2025-07-28,7月,2025-07-28
```

#### 3.2 测试导入

使用 ActiveAdmin 界面或直接调用导入服务：

```ruby
admin_user = AdminUser.first
file = File.open('test_import.csv')
service = FeeDetailImportService.new(file, admin_user)
result = service.import
puts result
```

#### 3.3 验证导入结果

```ruby
# 检查导入结果
result[:success] # 应为 true
result[:created_count] # 应为 2（IMP-TEST-001 和 IMP-TEST-002）
result[:skipped_due_to_error_count] # 应为 2（重复的 IMP-TEST-001 和缺少 external_fee_id 的记录）

# 检查数据库中的记录
FeeDetail.where(external_fee_id: 'IMP-TEST-001').count # 应为 1
FeeDetail.where(external_fee_id: 'IMP-TEST-002').count # 应为 1
```

### 4. 模型验证测试

在 Rails 控制台中测试模型验证：

```ruby
# 测试创建没有 external_fee_id 的记录（应失败）
fee_detail = FeeDetail.new(
  document_number: "TEST-005",
  fee_type: "测试费用",
  amount: 500,
  fee_date: Date.today,
  verification_status: FeeDetail::VERIFICATION_STATUS_PENDING
)
fee_detail.valid? # 应返回 false
fee_detail.errors.full_messages # 应包含 "External fee can't be blank"

# 测试创建重复 external_fee_id 的记录（应失败）
existing_id = FeeDetail.first.external_fee_id
fee_detail = FeeDetail.new(
  document_number: "TEST-006",
  fee_type: "测试费用",
  amount: 600,
  fee_date: Date.today,
  external_fee_id: existing_id,
  verification_status: FeeDetail::VERIFICATION_STATUS_PENDING
)
fee_detail.valid? # 应返回 false
fee_detail.errors.full_messages # 应包含 "External fee has already been taken"

# 测试创建有效记录（应成功）
fee_detail = FeeDetail.new(
  document_number: "TEST-007",
  fee_type: "测试费用",
  amount: 700,
  fee_date: Date.today,
  external_fee_id: "TEST-VALID-001",
  verification_status: FeeDetail::VERIFICATION_STATUS_PENDING
)
fee_detail.valid? # 应返回 true
fee_detail.save # 应返回 true
```

## 测试结果记录

### 1. 数据库迁移测试

- [ ] 迁移成功运行
- [ ] external_fee_id 字段有 NOT NULL 约束
- [ ] external_fee_id 字段有唯一索引
- [ ] 数据库中没有 nil 值的 external_fee_id
- [ ] 数据库中没有重复的 external_fee_id

### 2. 清理脚本测试

- [ ] 脚本成功运行
- [ ] 成功处理 nil 值的 external_fee_id
- [ ] 成功处理重复的 external_fee_id
- [ ] 保留了最近更新的记录，为其他记录生成了新的 ID

### 3. 导入功能测试

- [ ] 成功导入有效记录
- [ ] 正确拒绝没有 external_fee_id 的记录
- [ ] 正确拒绝重复的 external_fee_id 记录
- [ ] 导入服务返回了正确的结果统计

### 4. 模型验证测试

- [ ] 成功验证 external_fee_id 的存在性
- [ ] 成功验证 external_fee_id 的唯一性
- [ ] 成功创建有效记录

## 问题记录

在此记录测试过程中发现的任何问题：

1. 
2. 
3. 

## 结论

- [ ] 所有测试通过，修复方案在开发环境中有效
- [ ] 测试发现问题，需要进一步修复（见问题记录）

## 后续步骤

- [ ] 在测试环境中进行测试
- [ ] 准备生产环境部署
- [ ] 更新相关文档