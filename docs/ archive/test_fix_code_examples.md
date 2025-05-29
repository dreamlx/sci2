# 测试环境修复代码示例

本文档提供了修复测试环境中 `users.email` UNIQUE constraint 错误的具体代码示例。这些示例可以直接应用到项目中，以解决集成测试中的问题。

## 1. 修复 CompleteWorkflowTest 的 setup 方法

### 文件路径: `test/integration/complete_workflow_test.rb`

```ruby
# 原代码
setup do
  # Clean up data from previous test runs
  WorkOrder.delete_all
  ExpressReceipt.delete_all
  Reimbursement.delete_all
  FeeDetail.delete_all
  OperationHistory.delete_all

  @admin_user = create_admin_user
  sign_in @admin_user
end

# 修改后的代码
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

## 2. 统一 sign_in_admin 方法

### 文件路径: `test/integration/complete_workflow_test.rb`

```ruby
# 原代码
def sign_in_admin
  # Assuming Devise or similar for admin authentication
  admin_user = AdminUser.find_by(email: 'admin@example.com') || AdminUser.create!(email: 'admin@example.com', password: 'password')
  sign_in admin_user
end

# 修改后的代码
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

## 3. 修改 create_test_express_receipt 方法

### 文件路径: `test/integration/complete_workflow_test.rb`

```ruby
# 原代码
def create_test_express_receipt(document_number, tracking_number)
  ExpressReceipt.create!(
    document_number: document_number,
    tracking_number: tracking_number,
    receipt_date: Time.current,
    recipient: "测试收单人"
  )
end

# 修改后的代码
def create_test_express_receipt(document_number, tracking_number)
  ExpressReceipt.create!(
    document_number: document_number,
    tracking_number: tracking_number,
    receipt_date: Time.current,
    receiver: "receiver_#{SecureRandom.uuid}@example.com"  # 使用动态生成的邮箱
  )
end
```

## 4. 禁用测试并行执行（可选）

### 文件路径: `test/test_helper.rb`

```ruby
# 原代码
class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)
  
  # 其余代码...
end

# 修改后的代码
class ActiveSupport::TestCase
  # 注释掉并行测试
  # parallelize(workers: :number_of_processors)
  
  # 或设置为单线程
  parallelize(workers: 1)
  
  # 其余代码...
end
```

## 5. 使用数据库事务隔离测试（可选）

### 文件路径: `test/test_helper.rb`

```ruby
class ActiveSupport::TestCase
  # 添加或确保以下行存在
  self.use_transactional_tests = true
  
  # 其余代码...
end
```

## 6. 修复 ExpressReceipt 创建中的 receiver 字段

### 文件路径: `test/integration/complete_workflow_test.rb`

在测试中创建 ExpressReceipt 时，确保使用动态生成的邮箱：

```ruby
# 原代码
express_receipt = ExpressReceipt.create!(
  document_number: reimbursement.invoice_number,
  tracking_number: "SF-INT-001",
  receive_date: Time.current,
  receiver: @admin_user.email # 使用登录用户
)

# 修改后的代码（如果需要使用登录用户，确保该用户是动态创建的）
express_receipt = ExpressReceipt.create!(
  document_number: reimbursement.invoice_number,
  tracking_number: "SF-INT-001",
  receive_date: Time.current,
  receiver: "receiver_#{SecureRandom.uuid}@example.com" # 使用动态生成的邮箱
)
```

## 7. 确保 SecureRandom 被正确引入

### 文件路径: `test/test_helper.rb` 或 `test/integration/complete_workflow_test.rb`

```ruby
# 如果尚未引入，添加以下行
require 'securerandom'
```

## 应用修复后的验证步骤

1. 应用上述修改
2. 运行单个测试文件验证修复：
   ```bash
   bin/rails test test/integration/complete_workflow_test.rb
   ```
3. 如果单个测试通过，运行完整测试套件：
   ```bash
   bin/rails test
   ```

## 注意事项

1. 确保修改后的代码与项目的其他部分兼容
2. 如果禁用了并行测试，测试运行时间可能会增加
3. 在修复完成后，可以考虑重新启用并行测试，但需要确保测试之间的数据隔离
4. 这些修改主要针对测试环境，不会影响生产环境