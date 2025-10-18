# 手动测试目录

这个目录包含手动测试和验证脚本，用于特定的功能测试和问题排查。

## 文件说明

### 导出功能测试
- `test_export_functionality.rb` - 导出功能综合测试
- `test_excel_export_direct.rb` - Excel导出直接测试
- `test_export_permissions.rb` - 导出权限测试
- `test_simple_export.rb` - 简单导出测试

### 认证测试
- `test_authentication.rb` - 认证功能测试

### 检查脚本
- `check_capistrano_tasks.rb` - Capistrano任务检查
- `check_indexes.rb` - 数据库索引检查

### 修复脚本
- `fix_admin_user_data.rb` - 管理员用户数据修复
- `legacy_problem_code_virtual_field_fix.rb` - 遗留问题虚拟字段修复

### 诊断脚本
- `production_database_diagnostic.rb` - 生产数据库诊断

## 使用方法

### 运行测试

```bash
# 在 Rails 环境中运行单个测试
cd /path/to/sci2
rails runner spec/manual_tests/test_export_functionality.rb

# 运行认证测试
rails runner spec/manual_tests/test_authentication.rb
```

### 检查脚本

```bash
# 检查 Capistrano 任务
rails runner spec/manual_tests/check_capistrano_tasks.rb

# 检查数据库索引
rails runner spec/manual_tests/check_indexes.rb
```

### 修复脚本

```bash
# 修复管理员数据（请先备份数据库！）
rails runner spec/manual_tests/fix_admin_user_data.rb

# 运行生产诊断
rails runner spec/manual_tests/production_database_diagnostic.rb
```

## 注意事项

1. **生产环境使用前必须备份数据库**
2. 这些是手动测试脚本，不是自动化测试套件的一部分
3. 修复脚本可能对数据库产生永久性影响，请谨慎使用
4. 建议在开发或测试环境先验证这些脚本的效果
5. 运行前请仔细阅读脚本内容，了解其功能和副作用

## 集成到自动化测试

如果某个脚本的功能需要自动化，请将其从 `manual_tests/` 移动到适当的 RSpec 测试文件中：

- 单元测试 → `spec/models/`
- 集成测试 → `spec/integration/`
- 系统测试 → `spec/system/`
- 功能测试 → `spec/features/`