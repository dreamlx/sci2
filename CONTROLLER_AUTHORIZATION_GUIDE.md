# Controller层权限保护指南

## 概述

本指南详细说明了基于Policy Object的Controller层权限保护实现，确保API层面的安全性，防止通过直接API调用绕过UI权限控制。

## 核心组件

### 1. AuthorizationConcern

位置：`app/controllers/concerns/authorization_concern.rb`

这是统一的权限保护模块，提供以下功能：

- **统一权限检查**：基于Policy Object的权限验证
- **错误处理**：标准化的权限拒绝响应
- **日志记录**：详细的权限检查和安全日志
- **敏感操作保护**：双重权限验证机制

### 2. 权限保护方法

#### 基本权限保护
```ruby
# 在ActiveAdmin控制器中
controller do
  include AuthorizationConcern

  # 保护标准CRUD操作
  protect_action :index, with: 'ReimbursementPolicy', method: :can_index?
  protect_action :show, with: 'ReimbursementPolicy', method: :can_show?
  protect_action :create, with: 'ReimbursementPolicy', method: :can_create?
  protect_action :update, with: 'ReimbursementPolicy', method: :can_update?
  protect_action :destroy, with: 'ReimbursementPolicy', method: :can_destroy?
end
```

#### 成员操作权限保护
```ruby
# 保护member actions
protect_action :member_action, action_name: :assign, with: 'ReimbursementPolicy', method: :can_assign?
protect_action :member_action, action_name: :upload_attachment, with: 'ReimbursementPolicy', method: :can_upload_attachment?
```

#### 批量操作权限保护
```ruby
# 保护batch actions
protect_action :batch_action, action_name: :assign_to, with: 'ReimbursementPolicy', method: :can_batch_assign?
```

#### 集合操作权限保护
```ruby
# 保护collection actions
protect_action :collection_action, action_name: :import, with: 'ReimbursementPolicy', method: :can_import?
```

## 实施示例

### Reimbursement控制器

```ruby
# app/admin/reimbursements.rb
controller do
  include AuthorizationConcern

  # 标准CRUD权限保护
  protect_action :index, with: 'ReimbursementPolicy', method: :can_index?
  protect_action :show, with: 'ReimbursementPolicy', method: :can_show?
  protect_action :create, with: 'ReimbursementPolicy', method: :can_create?
  protect_action :update, with: 'ReimbursementPolicy', method: :can_update?
  protect_action :destroy, with: 'ReimbursementPolicy', method: :can_destroy?

  # 成员操作权限保护
  protect_action :member_action, action_name: :assign, with: 'ReimbursementPolicy', method: :can_assign?
  protect_action :member_action, action_name: :upload_attachment, with: 'ReimbursementPolicy', method: :can_upload_attachment?

  # 批量操作权限保护
  protect_action :batch_action, action_name: :assign_to, with: 'ReimbursementPolicy', method: :can_batch_assign?

  # 集合操作权限保护
  protect_action :collection_action, action_name: :import, with: 'ReimbursementPolicy', method: :can_import?

  # 敏感操作双重检查
  def show
    unless verify_sensitive_operation('ReimbursementPolicy', resource, 'view')
      return
    end
    # 业务逻辑...
  end
end
```

### AdminUser控制器

```ruby
# app/admin/admin_users.rb
controller do
  include AuthorizationConcern

  protect_action :index, with: 'AdminUserPolicy', method: :can_index?
  protect_action :create, with: 'AdminUserPolicy', method: :can_create?
  protect_action :update, with: 'AdminUserPolicy', method: :can_update?
  protect_action :destroy, with: 'AdminUserPolicy', method: :can_destroy?

  # 批量操作权限保护
  protect_action :batch_action, action_name: :软删除, with: 'AdminUserPolicy', method: :can_batch_soft_delete?
end
```

### Imports控制器（register_page）

```ruby
# app/admin/imports.rb
controller do
  include AuthorizationConcern

  # 全局权限保护 - 只有超级管理员可以访问
  before_action do
    unless current_admin_user&.super_admin?
      respond_to do |format|
        format.html {
          redirect_to admin_dashboard_path, alert: '您没有权限访问数据导入功能'
        }
        format.json {
          render json: {
            error: 'Authorization failed',
            message: '您没有权限访问数据导入功能',
            code: 403
          }, status: :forbidden
        }
      end
      return false
    end
  end
end
```

## 辅助方法

### 快速权限检查

```ruby
# 检查超级管理员权限
def sensitive_operation
  require_super_admin!
  # 业务逻辑...
end

# 检查管理员权限
def admin_operation
  require_admin_or_super_admin!
  # 业务逻辑...
end

# 自定义权限检查
def custom_operation
  unless require_permission?('CustomPolicy', 'can_perform?', resource)
    return
  end
  # 业务逻辑...
end
```

### 敏感操作保护

```ruby
# 对敏感操作进行双重验证
def delete_sensitive_data
  verify_sensitive_operation('DataPolicy', resource, 'destroy')
  # 业务逻辑...
end
```

## 安全特性

### 1. 多层权限验证

- **UI层**：通过Policy控制按钮和菜单显示
- **Controller层**：通过AuthorizationConcern进行API权限检查
- **Model层**：通过Policy和验证确保数据完整性

### 2. 详细的日志记录

#### 成功授权日志
```
[AUTH_SUCCESS] User: admin@example.com | Controller: Admin::ReimbursementsController | Action: index | IP: 192.168.1.100
```

#### 授权失败日志
```
[AUTH_FAILURE] User: user@example.com | Controller: Admin::ReimbursementsController | Action: assign | Reason: 您没有权限执行分配操作 | IP: 192.168.1.100
[SECURITY_ALERT] {"timestamp":"2024-01-01T12:00:00Z","event_type":"authorization_failure","user_email":"user@example.com","controller":"Admin::ReimbursementsController","action":"assign","reason":"您没有权限执行分配操作"}
```

#### 敏感操作日志
```
[SENSITIVE_OPERATION] User: admin@example.com | Operation: destroy | Resource: Reimbursement#123 | IP: 192.168.1.100
```

### 3. 参数过滤

敏感参数（如password、file等）在日志中会被过滤：
```ruby
# 原始参数
{ "email" => "user@example.com", "password" => "secret123" }

# 日志中显示
{ "email" => "user@example.com", "password" => "[FILTERED]" }
```

### 4. 响应格式标准化

#### HTML响应
```ruby
redirect_to admin_dashboard_path, alert: "您没有权限执行此操作"
```

#### JSON响应
```json
{
  "error": "Authorization failed",
  "message": "您没有权限执行此操作",
  "code": 403,
  "action": "assign"
}
```

## 测试策略

### 1. 单元测试

测试AuthorizationConcern的核心功能：
```ruby
# spec/controllers/authorization_concern_spec.rb
RSpec.describe AuthorizationConcern, type: :controller do
  # 测试权限检查、日志记录、错误处理等
end
```

### 2. 集成测试

测试实际控制器中的权限保护：
```ruby
# spec/controllers/admin_reimbursements_authorization_spec.rb
RSpec.describe "Admin::Reimbursements Authorization", type: :request do
  # 测试各种用户角色的权限
end
```

### 3. 安全测试

- **API绕过测试**：尝试通过直接API调用绕过UI权限
- **权限提升测试**：验证用户无法执行超出权限的操作
- **批量操作测试**：确保批量操作受到适当保护

## 最佳实践

### 1. 权限检查原则

- **最小权限原则**：默认拒绝，明确允许
- **双重检查**：敏感操作需要多重验证
- **统一接口**：使用AuthorizationConcern提供一致的权限检查

### 2. Policy设计

- **明确的方法命名**：使用`can_action?`格式
- **详细错误消息**：提供用户友好的权限拒绝说明
- **角色分离**：清晰区分不同角色的权限边界

### 3. 日志监控

- **定期审查**：检查权限失败日志，识别潜在安全威胁
- **告警机制**：对频繁的权限失败设置告警
- **审计追踪**：保留完整的权限检查记录

### 4. 测试覆盖

- **100%权限覆盖**：确保所有敏感操作都有权限检查
- **边界测试**：测试权限边界的各种情况
- **性能测试**：确保权限检查不影响系统性能

## 故障排除

### 常见问题

1. **权限检查失败**
   - 检查Policy方法是否存在
   - 验证用户角色和权限配置
   - 查看日志中的详细错误信息

2. **循环权限检查**
   - 避免在权限检查中触发其他权限检查
   - 使用`require_permission?`而不是`check_authorization`

3. **性能问题**
   - 优化Policy查询，避免N+1问题
   - 考虑权限检查结果缓存

### 调试技巧

```ruby
# 在开发环境中启用详细日志
Rails.logger.level = Logger::DEBUG

# 检查当前用户的权限
policy = ReimbursementPolicy.new(current_admin_user, resource)
Rails.logger.debug "Permission check result: #{policy.can_assign?}"
```

## 总结

通过实施这套Controller层权限保护系统，我们实现了：

1. **统一的安全机制**：所有Controller都使用相同的权限检查逻辑
2. **全面的日志记录**：完整的安全审计追踪
3. **灵活的权限控制**：支持各种类型的操作保护
4. **友好的错误处理**：标准化的权限拒绝响应
5. **强大的测试覆盖**：确保权限系统的可靠性

这个系统有效地防止了API层面的权限绕过，为整个应用提供了坚实的安全基础。