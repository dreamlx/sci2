---
name: "SCI2 报销单管理系统"
description: "SCI2 是一个基于 Rails 7 + ActiveAdmin 的企业报销单管理系统，提供完整的报销单生命周期管理、工单处理、操作历史追踪和通知状态管理功能。系统支持电子化和非电子化报销单，集成统一通知状态系统，支持用户分配和权限管理。"
category: "后端服务"
author: "SCI2 Team"
tags: ["Ruby on Rails", "ActiveAdmin", "PostgreSQL", "RSpec", "Devise", "Docker", "Capistrano"]
lastUpdated: "2026-01-04"
version: "v2.4.0"
---

# SCI2 报销单管理系统

## 项目概述

SCI2 是一个企业级报销单管理系统，旨在简化和自动化报销流程。系统提供完整的报销单生命周期管理，包括报销单创建、审核、沟通、快递收单等环节。通过 ActiveAdmin 提供友好的管理界面，支持多种工单类型（快递收单工单、审核工单、沟通工单），并实现了统一的通知状态系统，确保用户能够及时获取报销单的更新信息。

## 技术栈

### 后端
- **Ruby on Rails 7.x**: Web 应用框架
- **Ruby 3.4.2**: 编程语言（使用 rbenv 管理）
- **ActiveAdmin**: 管理界面框架
- **Devise**: 用户认证系统
- **state_machines-activerecord**: 状态机管理
- **Puma 6.0**: 应用服务器

### 数据库
- **PostgreSQL**: 开发、测试和生产环境（统一使用 PostgreSQL 15）
- **Docker Compose**: 开发和测试环境使用容器化 PostgreSQL

### 前端
- **Turbo Rails**: 页面动态更新
- **Stimulus Rails**: JavaScript 框架
- **Chart.js**: 数据可视化
- **esbuild**: JavaScript 打包工具
- **FontAwesome**: 图标库

### 测试
- **RSpec 6.0**: 测试框架
- **Capybara**: 集成测试
- **Selenium WebDriver**: 浏览器自动化
- **FactoryBot Rails**: 测试数据生成
- **Shoulda Matchers**: 匹配器库

### 部署
- **Docker & Docker Compose**: 容器化
- **Capistrano 3.20**: 自动化部署
- **Nginx**: Web 服务器

### 其他工具
- **Ransack**: 搜索和过滤
- **Roo**: Excel 文件处理
- **PaperTrail**: 版本控制
- **CanCanCan**: 权限管理
- **Rubocop**: 代码风格检查

## 项目结构

```
sci2/
├── app/
│   ├── admin/              # ActiveAdmin 配置
│   ├── assets/             # 静态资源
│   ├── channels/           # Action Cable 通道
│   ├── commands/           # 命令对象
│   ├── controllers/        # 控制器
│   ├── helpers/            # 视图助手
│   ├── javascript/         # JavaScript 文件
│   ├── jobs/               # 后台任务
│   ├── mailers/            # 邮件发送器
│   ├── models/             # 数据模型
│   │   ├── concerns/       # 模型关注点
│   │   ├── reimbursement.rb
│   │   ├── work_order.rb
│   │   ├── admin_user.rb
│   │   ├── operation_history.rb
│   │   ├── fee_detail.rb
│   │   ├── fee_type.rb
│   │   └── problem_type.rb
│   ├── policies/           # 授权策略
│   ├── repositories/       # 查询仓库
│   ├── services/           # 业务逻辑服务
│   │   ├── concerns/       # 服务关注点
│   │   ├── shared/        # 共享服务
│   │   ├── reimbursement_import_service.rb
│   │   ├── operation_history_import_service.rb
│   │   ├── express_receipt_import_service.rb
│   │   └── ...
│   └── views/              # 视图模板
├── bin/                    # 可执行脚本
├── config/                 # 配置文件
│   ├── environments/       # 环境配置
│   ├── initializers/       # 初始化配置
│   ├── database.yml        # 数据库配置
│   └── application.rb      # 应用配置
├── db/                     # 数据库相关
│   ├── migrate/            # 数据库迁移
│   ├── seeds.rb            # 种子数据
│   └── scripts/            # 数据库脚本
├── docs/                   # 项目文档
│   ├── 01-getting-started/ # 入门指南
│   ├── 02-architecture/    # 架构文档
│   ├── 03-development/     # 开发指南
│   ├── 04-deployment/      # 部署指南（已重组）
│   │   ├── 01-环境准备.md
│   │   ├── 02-开发环境部署.md
│   │   ├── 03-生产环境部署.md
│   │   ├── 04-数据库配置.md
│   │   ├── 05-Capistrano配置.md
│   │   ├── 06-故障排除.md
│   │   ├── production/
│   │   └── archive/
│   ├── 05-operations/     # 运维指南
│   └── 07-reference/       # 参考文档
├── lib/                    # 库文件
│   ├── assets/             # 资源编译
│   ├── capistrano/         # Capistrano 任务
│   └── tasks/              # Rake 任务
├── public/                 # 公共静态文件
├── spec/                   # 测试文件
│   ├── factories/          # FactoryBot 工厂
│   ├── models/             # 模型测试
│   ├── requests/          # 请求测试
│   ├── services/          # 服务测试
│   └── features/          # 功能测试
├── storage/                # 文件存储
├── test/                   # 测试辅助文件
├── .dockerignore           # Docker 忽略文件
├── .gitignore              # Git 忽略文件
├── .rubocop.yml            # Rubocop 配置
├── Capfile                 # Capistrano 配置
├── docker-compose.yml     # Docker Compose 配置
├── Gemfile                 # Ruby 依赖
├── Gemfile.lock            # 依赖锁定
├── package.json            # Node.js 依赖
├── Rakefile                # Rake 任务
└── README.md               # 项目说明
```

## 开发指南

### 代码风格

项目使用 Rubocop 进行代码风格检查，主要规范如下：

- **字符串字面量**: 使用单引号 (`'string'`)
- **行长度**: 最大 120 字符
- **方法长度**: 最大 25 行
- **类长度**: 最大 250 行
- **模块长度**: 最大 250 行
- **ABC 复杂度**: 最大 30
- **类和模块嵌套**: 使用嵌套风格

运行代码检查：
```bash
bundle exec rubocop
```

自动修复：
```bash
bundle exec rubocop -a
```

### 命名约定

- **文件命名**: 使用 snake_case，如 `reimbursement_service.rb`
- **类命名**: 使用 PascalCase，如 `ReimbursementService`
- **方法命名**: 使用 snake_case，如 `calculate_total_amount`
- **变量命名**: 使用 snake_case，如 `user_id`
- **常量命名**: 使用 SCREAMING_SNAKE_CASE，如 `STATUS_PENDING`
- **数据库表名**: 使用复数 snake_case，如 `reimbursements`
- **模型关联**: 使用描述性名称，如 `has_many :fee_details`

### Git 工作流

- **分支命名**:
  - 功能分支: `feature/feature-name`
  - 修复分支: `fix/issue-description`
  - 重构分支: `refactor/refactor-description`

- **提交信息格式**:
  ```
  <type>(<scope>): <subject>

  <body>

  <footer>
  ```
  类型包括: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

- **Pull Request 流程**:
  1. 从主分支创建功能分支
  2. 完成开发并提交代码
  3. 运行测试确保通过
  4. 创建 Pull Request 并描述变更
  5. 代码审查通过后合并

## 环境设置

### 开发要求

- **Ruby**: 3.4.2（使用 rbenv 管理）
- **Rails**: 7.1.5.1
- **Node.js**: 用于前端资源编译
- **PostgreSQL**: 15+（开发/测试使用 Docker Compose，生产环境直接安装）
- **Docker & Docker Compose**: 用于容器化开发
- **Capistrano**: 用于生产环境自动化部署

### 安装步骤

```bash
# 1. 克隆项目
git clone <repository-url>
cd sci2

# 2. 设置 Ruby 版本
rbenv local 3.4.2

# 3. 安装 Ruby 依赖
RBENV_VERSION=3.4.2 bundle install

# 4. 安装 Node.js 依赖
npm install

# 5. 配置数据库环境变量（可选）
cp .env.example .env
# 编辑 .env 文件设置数据库配置

# 6. 启动 PostgreSQL 容器（推荐）
docker compose up -d

# 7. 创建和迁移数据库（需要设置环境变量）
DATABASE_PORT=55000 DATABASE_USERNAME=sci2_test DATABASE_PASSWORD=test_password_123 RAILS_ENV=test bundle exec rails db:create
DATABASE_PORT=55000 DATABASE_USERNAME=sci2_test DATABASE_PASSWORD=test_password_123 RAILS_ENV=test bundle exec rails db:migrate
DATABASE_PORT=55000 DATABASE_USERNAME=sci2_test DATABASE_PASSWORD=test_password_123 RAILS_ENV=test bundle exec rails db:seed

# 8. 启动开发服务器
RBENV_VERSION=3.4.2 rails server
```

### 环境变量

```env
# 数据库配置
DATABASE_HOST=localhost
DATABASE_PORT=55000
DATABASE_USERNAME=sci2_test
DATABASE_PASSWORD=test_password_123
DATABASE_NAME=sci2_development
DATABASE_NAME_TEST=sci2_test
DATABASE_NAME_PROD=sci2_production

# Rails 配置
RAILS_MAX_THREADS=10
RAILS_ENV=development
RAILS_LOG_TO_STDOUT=true

# 其他配置
SECRET_KEY_BASE=<your-secret-key>
```

## 核心功能实现

### 报销单管理 (Reimbursement)

报销单是系统的核心模型，管理报销单的完整生命周期。

```ruby
class Reimbursement < ApplicationRecord
  # 状态常量
  STATUS_PENDING = 'pending'.freeze
  STATUS_PROCESSING = 'processing'.freeze
  STATUS_CLOSED = 'closed'.freeze

  # 状态机
  state_machine :status, initial: :pending do
    event :start_processing do
      transition pending: :processing
    end

    event :close_processing do
      transition processing: :closed
    end

    event :reopen_to_processing do
      transition closed: :processing
    end
  end

  # 检查是否有未读更新
  def has_unread_updates?
    has_updates? && (last_viewed_at.nil? || (last_update_at && last_update_at > last_viewed_at))
  end

  # 更新通知状态
  def update_notification_status!
    new_last_update_at = calculate_last_update_time
    new_has_updates = last_viewed_at.nil? || new_last_update_at > last_viewed_at

    update_columns(
      last_update_at: new_last_update_at,
      has_updates: new_has_updates
    )
  end
end
```

### 工单系统 (WorkOrder)

使用 STI (Single Table Inheritance) 实现不同类型的工单。

```ruby
class WorkOrder < ApplicationRecord
  # STI 配置
  self.inheritance_column = :type

  # 状态机
  state_machine :status, initial: :pending do
    state :pending, value: 'pending'
    state :processing, value: 'processing'
    state :approved, value: 'approved'
    state :rejected, value: 'rejected'
    state :completed, value: 'completed'

    event :start_processing do
      transition pending: :processing
    end

    event :approve do
      transition %i[pending processing] => :approved
    end

    event :reject do
      transition %i[pending processing] => :rejected
    end

    event :complete do
      transition %i[approved rejected] => :completed, if: -> { is_a?(ExpressReceiptWorkOrder) }
    end
  end

  # 同步费用明细验证状态
  def sync_fee_details_verification_status
    fee_detail_ids = fee_details.pluck(:id)
    if fee_detail_ids.any?
      FeeDetailStatusService.new(fee_detail_ids).update_status
    end
  end
end

# 快递收单工单
class ExpressReceiptWorkOrder < WorkOrder
  # 快递工单特定逻辑
end

# 审核工单
class AuditWorkOrder < WorkOrder
  # 审核工单特定逻辑
end

# 沟通工单
class CommunicationWorkOrder < WorkOrder
  # 沟通工单特定逻辑
end
```

### 数据导入服务

系统提供多种数据导入服务，支持从 Excel 文件导入数据。

```ruby
class BaseImportService
  # 基础导入服务类
  def initialize(file_path)
    @file_path = file_path
    @errors = []
    @success_count = 0
  end

  def import
    raise NotImplementedError
  end

  protected

  def log_error(message)
    @errors << message
  end
end

class ReimbursementImportService < BaseImportService
  def import
    spreadsheet = Roo::Spreadsheet.open(@file_path)
    header = spreadsheet.row(1)

    (2..spreadsheet.last_row).each do |i|
      row = spreadsheet.row(i)
      process_row(row, header)
    end

    { success_count: @success_count, errors: @errors }
  end

  private

  def process_row(row, header)
    # 处理每一行数据
    reimbursement = Reimbursement.new(extract_attributes(row, header))
    if reimbursement.save
      @success_count += 1
    else
      log_error("Row #{i}: #{reimbursement.errors.full_messages.join(', ')}")
    end
  end
end
```

### 统一通知状态系统

```ruby
# 在 Reimbursement 模型中
def has_updates?
  operation_histories.exists? || express_receipt_work_orders.exists?
end

def has_unread_updates?
  has_updates? && (last_viewed_at.nil? || (last_update_at && last_update_at > last_viewed_at))
end

def mark_as_viewed!
  update!(
    last_viewed_at: Time.current,
    has_updates: false,
    last_viewed_operation_histories_at: Time.current,
    last_viewed_express_receipts_at: Time.current
  )
end

# 查询范围
scope :with_unread_updates, lambda {
  where(has_updates: true)
    .where('last_viewed_at IS NULL OR last_update_at > last_viewed_at')
}

scope :assigned_with_unread_updates, lambda { |user_id|
  assigned_to_user(user_id).with_unread_updates
}
```

## 测试策略

### 单元测试

- **测试框架**: RSpec 6.0
- **测试数据**: FactoryBot Rails
- **匹配器**: Shoulda Matchers
- **覆盖率**: Simplecov

运行单元测试：
```bash
# 运行所有测试
DATABASE_PORT=55000 RAILS_ENV=test bundle exec rspec

# 运行特定测试文件
DATABASE_PORT=55000 RAILS_ENV=test bundle exec rspec spec/models/reimbursement_spec.rb

# 运行特定测试
DATABASE_PORT=55000 RAILS_ENV=test bundle exec rspec spec/models/reimbursement_spec.rb:42
```

### 集成测试

- **测试场景**: API 端点、控制器逻辑
- **测试工具**: RSpec Rails, Rails Controller Testing

运行集成测试：
```bash
DATABASE_PORT=55000 RAILS_ENV=test bundle exec rspec spec/requests/
```

### 端到端测试

- **测试工作流**: 完整的用户操作流程
- **自动化工具**: Capybara + Selenium WebDriver

运行端到端测试：
```bash
DATABASE_PORT=55000 RAILS_ENV=test bundle exec rspec spec/features/
```

### 测试文件组织

```
spec/
├── factories/              # FactoryBot 工厂定义
│   ├── reimbursements.rb
│   ├── work_orders.rb
│   └── admin_users.rb
├── models/                 # 模型测试
│   ├── reimbursement_spec.rb
│   ├── work_order_spec.rb
│   └── admin_user_spec.rb
├── requests/               # 请求测试
│   ├── admin/
│   └── api/
├── services/               # 服务测试
│   ├── reimbursement_import_service_spec.rb
│   └── operation_history_import_service_spec.rb
├── features/               # 功能测试
│   ├── admin/
│   └── user/
├── rails_helper.rb         # Rails 测试配置
└── spec_helper.rb          # RSpec 基础配置
```

## 部署指南

### 构建过程

```bash
# 预编译资源
RAILS_ENV=production bundle exec rails assets:precompile

# 运行数据库迁移
RAILS_ENV=production bundle exec rails db:migrate

# 运行种子数据
RAILS_ENV=production bundle exec rails db:seed
```

### 部署步骤

1. **准备生产环境**
   - 配置服务器环境
   - 安装必要的依赖
   - 设置环境变量

2. **配置环境变量**
   ```bash
   # 在服务器上设置环境变量
   export DATABASE_HOST=<database-host>
   export DATABASE_PORT=<database-port>
   export DATABASE_USERNAME=<username>
   export DATABASE_PASSWORD=<password>
   export DATABASE_NAME_PROD=sci2_production
   export SECRET_KEY_BASE=<secret-key>
   export RAILS_ENV=production
   ```

3. **执行部署脚本**
   ```bash
   # 使用 Capistrano 部署
   bundle exec cap production deploy

   # 或使用部署脚本
   ./scripts/deploy/deploy_production.sh
   ```

4. **验证部署结果**
   - 检查应用状态
   - 验证数据库连接
   - 测试关键功能

### Capistrano 部署

```bash
# 首次部署
bundle exec cap production deploy:setup
bundle exec cap production deploy

# 常规部署
bundle exec cap production deploy

# 回滚
bundle exec cap production deploy:rollback

# 查看部署状态
bundle exec cap production deploy:status
```

### 环境变量

```env
# 生产环境必需的环境变量
DATABASE_HOST=<database-host>
DATABASE_PORT=<database-port>
DATABASE_USERNAME=<username>
DATABASE_PASSWORD=<password>
DATABASE_NAME_PROD=sci2_production
SECRET_KEY_BASE=<your-secret-key>
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_MAX_THREADS=20
```

## 性能优化

### 数据库优化

- **索引优化**: 为常用查询字段添加索引
- **查询优化**: 使用 `includes` 预加载关联，避免 N+1 查询
- **批量操作**: 使用批量插入和更新

```ruby
# 预加载关联
Reimbursement.includes(:fee_details, :work_orders).all

# 批量插入
FeeDetail.insert_all(attributes_array)

# 批量更新
FeeDetail.where(id: ids).update_all(status: 'verified')
```

### 缓存策略

- **查询缓存**: 使用 Rails 查询缓存
- **片段缓存**: 缓存频繁访问的视图片段
- **HTTP 缓存**: 使用 ETag 和 Last-Modified

```ruby
# 查询缓存
Rails.cache.fetch('all_fee_types', expires_in: 1.hour) do
  FeeType.all.to_a
end

# 片段缓存
<% cache @reimbursement do %>
  <%= render @reimbursement %>
<% end %>
```

### 导入优化

- **批量导入**: 使用批量插入减少数据库操作
- **事务处理**: 使用事务确保数据一致性
- **进度跟踪**: 实时显示导入进度

```ruby
class OptimizedReimbursementImportService < BaseImportService
  BATCH_SIZE = 100

  def import
    spreadsheet = Roo::Spreadsheet.open(@file_path)
    header = spreadsheet.row(1)

    (2..spreadsheet.last_row).each_slice(BATCH_SIZE) do |batch|
      process_batch(batch, header)
    end

    { success_count: @success_count, errors: @errors }
  end

  private

  def process_batch(batch, header)
    Reimbursement.transaction do
      batch.each do |i|
        row = spreadsheet.row(i)
        process_row(row, header)
      end
    end
  end
end
```

## 安全考虑

### 数据安全

- **输入验证**: 使用 Rails 强参数和模型验证
- **SQL 注入防护**: 使用参数化查询
- **XSS 防护**: Rails 自动转义输出

```ruby
# 强参数
def reimbursement_params
  params.require(:reimbursement).permit(
    :invoice_number,
    :status,
    :is_electronic,
    fee_details_attributes: [:id, :amount, :description]
  )
end

# 模型验证
class Reimbursement < ApplicationRecord
  validates :invoice_number, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
end
```

### 认证与授权

- **用户认证**: 使用 Devise 进行用户认证
- **权限控制**: 使用 CanCanCan 进行权限管理
- **软删除**: 用户软删除机制

```ruby
# AdminUser 模型
class AdminUser < ApplicationRecord
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  enum role: { admin: 'admin', super_admin: 'super_admin', regular: 'regular' }
  enum status: { active: 'active', inactive: 'inactive', suspended: 'suspended', deleted: 'deleted' }

  # 只允许活跃用户登录
  def active_for_authentication?
    super && active?
  end

  # 软删除
  def soft_delete
    update(status: 'deleted', deleted_at: Time.current)
  end
end

# Ability 类
class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= AdminUser.new

    if user.super_admin?
      can :manage, :all
    elsif user.admin?
      can :manage, Reimbursement
      can :read, WorkOrder
    else
      can :read, Reimbursement, assignee_id: user.id
    end
  end
end
```

### 敏感数据保护

- **环境变量**: 敏感配置存储在环境变量中
- **加密**: 使用 Rails 加密机制
- **日志过滤**: 过滤敏感信息

```ruby
# config/initializers/filter_parameter_logging.rb
Rails.application.config.filter_parameters += [
  :password,
  :password_confirmation,
  :secret_key,
  :database_password
]
```

## 监控和日志

### 应用监控

- **性能监控**: 使用 Rails 日志和性能分析
- **错误追踪**: 使用 Better Errors 开发环境调试
- **用户行为分析**: 通过操作历史记录追踪

```ruby
# 操作历史记录
class OperationHistory < ApplicationRecord
  belongs_to :reimbursement, foreign_key: 'document_number', primary_key: 'invoice_number'

  validates :operation_type, presence: true
  validates :operator, presence: true
end

# 记录操作
def log_operation(operation_type, operator, details)
  OperationHistory.create!(
    document_number: invoice_number,
    operation_type: operation_type,
    operator: operator,
    details: details
  )
end
```

### 日志管理

- **日志级别**: debug, info, warn, error, fatal
- **日志格式**: 结构化日志格式
- **日志存储**: 文件存储，按日期轮转

```ruby
# config/environments/production.rb
config.log_level = :info
config.log_tags = [:request_id]
config.logger = ActiveSupport::Logger.new(STDOUT)
  .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
  .then  { |logger| ActiveSupport::TaggedLogging.new(logger) }
```

## 常见问题

### 问题 1: 数据库连接失败

**解决方案**:
1. 检查数据库服务是否运行
   ```bash
   docker ps | grep postgres
   ```

2. 验证环境变量配置
   ```bash
   echo $DATABASE_HOST
   echo $DATABASE_PORT
   ```

3. 检查数据库配置文件
   ```bash
   cat config/database.yml
   ```

### 问题 2: 资源预编译失败

**解决方案**:
1. 清理预编译资源
   ```bash
   RAILS_ENV=production bundle exec rails assets:clobber
   ```

2. 重新预编译
   ```bash
   RAILS_ENV=production bundle exec rails assets:precompile
   ```

3. 检查 Node.js 和 npm 版本
   ```bash
   node --version
   npm --version
   ```

### 问题 3: 测试数据库迁移失败

**解决方案**:
1. 重置测试数据库
   ```bash
   RAILS_ENV=test bundle exec rails db:reset
   ```

2. 检查迁移文件
   ```bash
   RAILS_ENV=test bundle exec rails db:migrate:status
   ```

3. 运行特定迁移
   ```bash
   RAILS_ENV=test bundle exec rails db:migrate:up VERSION=20250101000000
   ```

### 问题 4: Docker 容器端口冲突

**解决方案**:
1. 检查端口占用
   ```bash
   lsof -i :55000
   ```

2. 修改 docker-compose.yml 中的端口映射
   ```yaml
   services:
     postgres_test:
       ports:
         - "55001:5432"  # 使用不同的端口
   ```

3. 重启容器
   ```bash
   docker compose down
   docker compose up -d
   ```

## 参考资源

- [Ruby on Rails 官方文档](https://guides.rubyonrails.org/)
- [ActiveAdmin 文档](https://activeadmin.info/)
- [Devise 文档](https://github.com/heartcombo/devise)
- [RSpec 文档](https://rspec.info/)
- [Capistrano 文档](https://capistranorb.com/)
- [Docker 文档](https://docs.docker.com/)
- [PostgreSQL 文档](https://www.postgresql.org/docs/)

## 更新日志

### v1.0.0 (2025-01-01)

- 初始版本发布
- 实现报销单管理功能
- 实现工单系统（快递收单、审核、沟通）
- 实现统一通知状态系统
- 实现数据导入功能
- 实现用户认证和权限管理
