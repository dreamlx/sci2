# SCI2 报销单管理系统

## 📋 项目概述

SCI2 是一个基于 Rails 7 + ActiveAdmin 的企业报销单管理系统，提供完整的报销单生命周期管理、工单处理、操作历史追踪和通知状态管理功能。

## 🛠️ 技术栈

- **后端框架**: Ruby on Rails 7.x
- **Ruby版本**: ruby 3.4.2(rbenv)
- **管理界面**: ActiveAdmin
- **数据库**: PostgreSQL/MySQL
- **测试框架**: RSpec
- **状态机**: state_machines gem
- **认证系统**: Devise

## 🏗️ 核心架构

### 主要模型

#### 📄 Reimbursement (报销单)
- 报销单的核心模型，包含申请人信息、金额、状态等
- 支持电子化和非电子化报销单
- 集成统一通知状态系统
- 支持用户分配和权限管理

#### 🎫 WorkOrder (工单) - STI继承
- **ExpressReceiptWorkOrder**: 快递收单工单
- **AuditWorkOrder**: 审核工单  
- **CommunicationWorkOrder**: 沟通工单
- 支持状态机管理工单生命周期

#### 📊 OperationHistory (操作历史)
- 记录报销单的所有操作历史
- 支持导入外部系统数据
- 自动触发通知状态更新

#### 👥 AdminUser (管理员用户)
- 基于Devise的用户认证系统
- 支持角色权限管理
- 集成报销单分配功能

### 关键功能模块

#### 🔔 统一通知状态系统 ✅
- **统一显示**: 将原有的 `+快` (快递) 和 `+记` (操作记录) 合并为 "有更新" 统一状态
- **自动回调**: 操作历史和快递工单创建后自动触发通知更新
- **用户隔离**: 不同用户只能看到分配给自己的通知
- **智能排序**: 按通知状态和更新时间排序
- **核心方法**:
  - `has_unread_updates?()` - 检查是否有未读更新
  - `update_notification_status!()` - 更新通知状态
  - `mark_as_viewed!()` - 标记为已查看

#### 📥 数据导入系统
- **操作历史导入**: `OperationHistoryImportService`
- **快递收单导入**: `ExpressReceiptImportService`
- **报销单导入**: `ReimbursementImportService`
- **费用明细导入**: `FeeDetailImportService`

#### 🔍 查询和过滤
- **分配查询**: `assigned_to_user(user_id)`
- **通知过滤**: `with_unread_updates`, `assigned_with_unread_updates`
- **状态排序**: `ordered_by_notification_status`

## 🚀 快速开始

### 环境要求
```bash
Ruby 3.4.2 (使用 rbenv 管理)
Rails 7.x
MySQL (生产环境)
```

### Ruby 环境设置
项目使用 rbenv 管理 Ruby 版本，详细设置请参考 [Ruby 环境设置文档](docs/ruby_environment_setup.md)。

```bash
# 检查 rbenv 安装
rbenv --version

# 设置本地项目 Ruby 版本
rbenv local 3.4.2

# 安装依赖
RBENV_VERSION=3.4.2 bundle install
```

### 数据库设置
```bash
# 开发环境 (SQLite)
rails db:create
rails db:migrate
rails db:seed

# 生产环境 (MySQL) - 通过部署脚本自动处理
```

### 启动服务
```bash
# 开发环境
rails server

# 或使用 rbenv 指定版本
RBENV_VERSION=3.4.2 rails server
```

### 运行测试
```bash
# 运行所有测试
RBENV_VERSION=3.4.2 bundle exec rspec

# 运行通知系统测试
RBENV_VERSION=3.4.2 bundle exec rspec spec/models/reimbursement_notification_spec.rb
RBENV_VERSION=3.4.2 bundle exec rspec spec/integration/reimbursement_notification_integration_spec.rb
```

## 🚀 部署指南

### 部署概述
项目使用 Capistrano 进行自动化部署，支持从本地开发环境直接推送到服务器，无需服务器访问 GitHub。

### 环境配置
- **生产环境**: 阿里云服务器 (8.136.10.88)
- **测试环境**: 阿里云服务器 (47.97.35.0)
- **部署用户**: deploy
- **数据库**: MySQL (MariaDB 10.11.11)

### 快速部署

#### 方法一：使用部署脚本（推荐）
```bash
# 生产环境部署
./scripts/deploy_production.sh

# 测试环境部署
./scripts/deploy_staging.sh
```

#### 方法二：手动部署
```bash
# 生产环境
RBENV_VERSION=3.4.2 bundle exec cap production deploy

# 测试环境
RBENV_VERSION=3.4.2 bundle exec cap staging deploy
```

### 部署前准备
1. **确保本地代码已提交**
   ```bash
   git add .
   git commit -m "部署更新"
   ```

2. **检查 Ruby 版本**
   ```bash
   rbenv versions | grep 3.4.2
   ```

3. **验证 SSH 连接**
   ```bash
   ssh root@8.136.10.88  # 生产环境
   ssh root@47.97.35.0   # 测试环境
   ```

### 部署流程
1. **代码推送**: 从本地 Git 仓库推送到服务器
2. **依赖安装**: 自动安装 gem 依赖
3. **数据库迁移**: 执行数据库迁移
4. **资产预编译**: 编译静态资源
5. **服务重启**: 重启 Puma 服务
6. **防火墙配置**: 自动开放必要端口

### 部署后验证
```bash
# 检查服务状态
ssh root@8.136.10.88 "systemctl status puma"

# 查看应用日志
ssh root@8.136.10.88 "tail -f /opt/sci2/shared/log/puma.error.log"

# 访问应用
curl http://8.136.10.88:3000
```

### 故障排除
常见问题和解决方案请参考 [Ruby 环境设置文档](docs/ruby_environment_setup.md) 中的"常见问题解决"部分。

## 📊 数据库结构

### 核心表
- `reimbursements` - 报销单主表
- `work_orders` - 工单表 (STI)
- `operation_histories` - 操作历史表
- `admin_users` - 管理员用户表
- `fee_details` - 费用明细表

### 关联表
- `reimbursement_assignments` - 报销单分配关系
- `work_order_fee_details` - 工单费用明细关联
- `work_order_operations` - 工单操作记录

## 🧪 测试覆盖

### 单元测试
- ✅ **21个测试用例** - 统一通知状态系统
- ✅ 模型验证和关联测试
- ✅ 服务类功能测试

### 集成测试  
- ✅ **9个测试用例** - 完整业务流程模拟
- ✅ 多用户协作场景
- ✅ 数据导入场景
- ✅ 边界情况处理

## 📈 最新更新

### v2.1.0 (2025-08-06) ✅
- **统一通知状态系统完成**
  - 合并 `+快` 和 `+记` 为统一的 "有更新" 状态
  - 实现自动回调机制
  - 添加用户分配过滤功能
  - 完善测试覆盖 (30个测试用例)

### 开发中功能
- 📋 docs/ 目录文档整理和更新
- 🔧 系统性能优化
- 📊 报表功能增强

## 🎯 ActiveAdmin 管理界面

访问 `/admin` 进入管理界面，主要功能：

### 报销单管理
- 📋 报销单列表和详情查看
- 🔍 高级搜索和过滤
- 📊 状态统计和报表
- 🔔 统一通知状态显示

### 工单管理
- 🎫 工单创建和处理
- 📈 工单状态跟踪
- 💬 沟通记录管理

### 数据导入
- 📥 批量导入操作历史
- 📦 快递收单批量导入
- 📊 导入结果统计

## 🔧 开发指南

### 添加新功能
1. 创建相应的模型和迁移
2. 编写服务类处理业务逻辑
3. 配置ActiveAdmin资源
4. 编写完整的测试用例

### 测试规范
- 单元测试覆盖所有模型方法
- 集成测试验证完整业务流程
- 使用工厂模式创建测试数据

### 代码规范
- 遵循Rails最佳实践
- 使用服务对象处理复杂业务逻辑
- 保持模型精简，逻辑清晰

## 📞 技术支持

如需技术支持或有疑问，请：
1. 查看 `docs/` 目录中的详细文档
2. 运行测试确保功能正常
3. 检查日志文件排查问题

## 📝 更新日志

详细的更新日志请查看 Git 提交记录：
```bash
git log --oneline --graph
```

---

**最后更新**: 2025-08-28
**版本**: v2.2.0
**状态**: 部署系统优化 ✅ 完成

### v2.2.0 (2025-08-28) ✅
- **部署系统优化**
  - 添加 Ruby 环境设置文档
  - 创建自动化部署脚本
  - 修改部署配置支持本地 Git 推送
  - 更新 README 添加完整部署指南
  - 解决国内服务器无法访问 GitHub 的问题
