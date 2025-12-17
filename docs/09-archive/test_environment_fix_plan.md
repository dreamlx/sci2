# SCI2 测试环境修复计划

## 问题概述

在集成测试阶段遇到 `users.email` UNIQUE constraint 错误，导致测试失败。这个问题出现在 `CompleteWorkflowTest` 中，阻碍了项目的进展。

## 问题分析

通过代码分析，发现以下几个可能导致问题的因素：

1. **测试并行执行**：
   - `test/test_helper.rb` 中设置了 `parallelize(workers: :number_of_processors)`
   - 多个测试进程可能同时创建具有相同邮箱的用户

2. **不一致的用户创建方法**：
   - `CompleteWorkflowTest` 中使用 `create_admin_user` 方法创建动态邮箱的管理员
   - `sign_in_admin` 方法中尝试创建固定邮箱 'admin@example.com' 的管理员

3. **测试数据清理不完整**：
   - 测试的 `setup` 方法清理了多个表，但没有清理 User 和 AdminUser 表

4. **ExpressReceipt 与 User 邮箱关联**：
   - ExpressReceipt 模型中的 receiver 字段使用了 admin_user.email

## 修复步骤

### 步骤1：修复 CompleteWorkflowTest 的 setup 方法

在 `test/integration/complete_workflow_test.rb` 文件中，修改 `setup` 方法，添加 User 和 AdminUser 表的清理：

```ruby
setup do
  # Clean up data from previous test runs
  WorkOrder.delete_all
  ExpressReceipt.delete_all
  Reimbursement.delete_all
  FeeDetail.delete_all
  OperationHistory.delete_all
  User.delete_all        # 添加这行
  AdminUser.delete_all   # 添加这行

  @admin_user = create_admin_user
  sign_in @admin_user
end
```

### 步骤2：统一 sign_in_admin 方法

在 `test/integration/complete_workflow_test.rb` 文件中，修改 `sign_in_admin` 方法，确保使用动态生成的邮箱：

```ruby
def sign_in_admin
  admin_user = AdminUser.create!(
    email: "admin_#{SecureRandom.uuid}@example.com",
    password: 'password',
    password_confirmation: 'password'
  )
  sign_in admin_user
  admin_user
end
```

### 步骤3：修改 create_test_express_receipt 方法

在 `test/integration/complete_workflow_test.rb` 文件中，修改 `create_test_express_receipt` 方法，使用动态生成的收件人：

```ruby
def create_test_express_receipt(document_number, tracking_number)
  ExpressReceipt.create!(
    document_number: document_number,
    tracking_number: tracking_number,
    receipt_date: Time.current,
    receiver: "receiver_#{SecureRandom.uuid}@example.com"  # 使用动态生成的邮箱
  )
end
```

### 步骤4（可选）：禁用测试并行执行

如果上述修改后问题仍然存在，可以在 `test/test_helper.rb` 中暂时禁用测试并行执行：

```ruby
class ActiveSupport::TestCase
  # 注释掉并行测试
  # parallelize(workers: :number_of_processors)
  
  # 或设置为单线程
  parallelize(workers: 1)
  
  # 其余代码保持不变
end
```

### 步骤5（可选）：使用数据库事务隔离测试

确保在 `test/test_helper.rb` 中启用事务测试：

```ruby
class ActiveSupport::TestCase
  # 使用事务包装每个测试
  self.use_transactional_tests = true
  
  # 其余代码保持不变
end
```

## 验证方法

1. 实施步骤1-3的修改
2. 运行集成测试：`bin/rails test test/integration/complete_workflow_test.rb`
3. 如果测试仍然失败，实施步骤4和5
4. 再次运行测试验证问题是否解决

## 注意事项

1. 修改后确保所有测试都能正常运行，不仅仅是 `CompleteWorkflowTest`
2. 如果禁用并行测试，可能会导致测试运行时间增加
3. 在修复完成后，可以考虑重新启用并行测试，但需要确保测试之间的数据隔离