# Capistrano数据库部署修复指南

## 问题描述

之前的部署存在以下问题：
1. SQLite开发数据库文件被部署到生产环境
2. MySQL环境变量未正确设置
3. 生产环境意外使用了开发数据

## 解决方案

### 1. 修改的文件

#### `config/deploy.rb`
- 添加了`copy_exclude`排除SQLite文件
- 新增环境变量设置任务
- 新增数据库设置任务

#### `config/deploy/production.rb`
- 添加数据库凭据配置
- **重要：需要修改实际的MySQL用户名和密码**

#### `lib/capistrano/tasks/database.rake`
- 自动创建MySQL数据库和用户
- 测试数据库连接
- 提供数据库重置功能

#### `.gitignore`
- 确保SQLite文件不被提交到Git

### 2. 部署前准备

#### 步骤1：修改数据库凭据
编辑 `config/deploy/production.rb`：

```ruby
# 将这些改为你的实际MySQL凭据
set :database_username, 'your_actual_mysql_username'
set :database_password, 'your_actual_mysql_password'
```

#### 步骤2：确保MySQL已安装
在生产服务器上确保MySQL已安装并运行：

```bash
# 检查MySQL状态
sudo systemctl status mysql
# 或
sudo systemctl status mysqld
```

#### 步骤3：提交更改
```bash
git add .
git commit -m "Fix database deployment configuration"
git push origin main
```

### 3. 部署流程

#### 完整重新部署
```bash
# 清理现有部署（如果需要）
cap production deploy:cleanup

# 执行新的部署
cap production deploy
```

#### 部署过程中会自动执行：
1. 排除SQLite文件
2. 设置环境变量
3. 创建MySQL数据库和用户
4. 运行数据库迁移
5. 测试数据库连接

### 4. 验证部署

#### 检查数据库连接
```bash
# 在生产服务器上
cd /opt/sci2/current
source /opt/sci2/shared/config/environment
bundle exec rails runner "puts ActiveRecord::Base.connection.adapter_name" RAILS_ENV=production
bundle exec rails runner "puts ActiveRecord::Base.connection.current_database" RAILS_ENV=production
```

#### 检查数据
```bash
# 应该显示空的或只有基础数据的数据库
bundle exec rails runner "puts Reimbursement.count" RAILS_ENV=production
```

### 5. 故障排除

#### 如果MySQL连接失败
1. 检查MySQL服务状态
2. 验证用户名和密码
3. 手动创建数据库和用户：

```sql
mysql -u root -p
CREATE DATABASE sci2_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'your_username'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON sci2_production.* TO 'your_username'@'localhost';
FLUSH PRIVILEGES;
```

#### 如果仍然看到开发数据
1. 检查是否有SQLite文件残留：
```bash
find /opt/sci2 -name "*.sqlite3" -type f
```

2. 删除任何SQLite文件：
```bash
rm -f /opt/sci2/current/db/*.sqlite3
rm -f /opt/sci2/shared/db/*.sqlite3
```

3. 重新部署：
```bash
cap production deploy
```

### 6. 数据库重置（危险操作）

如果需要完全重置生产数据库：

```bash
# 使用Capistrano任务
cap production database:reset_production

# 或手动执行
cd /opt/sci2/current
source /opt/sci2/shared/config/environment
bundle exec rails db:drop RAILS_ENV=production
bundle exec rails db:create RAILS_ENV=production
bundle exec rails db:migrate RAILS_ENV=production
```

## 重要提醒

1. **修改数据库凭据**：必须在`config/deploy/production.rb`中设置正确的MySQL用户名和密码
2. **备份数据**：在重新部署前备份任何重要数据
3. **测试连接**：部署后验证数据库连接和数据状态
4. **环境隔离**：确保开发、测试、生产环境完全分离

## 联系支持

如果遇到问题，请检查：
1. MySQL服务状态
2. 网络连接
3. 用户权限
4. 防火墙设置