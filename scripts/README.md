# Scripts 脚本目录

本目录包含项目的所有脚本，按用途分类组织。

## 目录结构

```
scripts/
├── dev/           # 本地开发脚本
├── deploy/        # 部署相关脚本
└── maintenance/   # 维护和诊断脚本
```

## dev/ - 开发脚本

用于本地开发环境的脚本。

| 脚本 | 说明 |
|------|------|
| `start_rails_simple.sh` | 简单启动 Rails 服务器 |
| `start_rails_with_db.sh` | 启动 Rails 并确保数据库就绪 |
| `start_rails_with_proxy.sh` | 启动 Rails 并配置代理 |
| `setup-test-db.sh` | 设置测试数据库 |
| `stop-test-db.sh` | 停止测试数据库 |
| `doc-update-helper.sh` | 文档更新辅助工具 |

## deploy/ - 部署脚本

用于服务器部署和配置的脚本。

| 脚本 | 说明 |
|------|------|
| `deploy.sh` | 主部署脚本 |
| `deploy_with_capistrano.sh` | Capistrano 部署 |
| `deploy_production.sh` | 生产环境部署 |
| `deploy_staging.sh` | 预发布环境部署 |
| `setup_puma_systemd.sh` | 配置 Puma systemd 服务 |
| `server_setup.sh` | 服务器初始化 |
| `install_dependencies.sh` | 安装服务器依赖 |
| `setup_ssh_key.sh` | 配置 SSH 密钥 |

## maintenance/ - 维护脚本

用于系统维护和诊断的脚本。

| 脚本 | 说明 |
|------|------|
| `production_database_diagnostic.rb` | 生产数据库诊断 |
| `fix_admin_user_data.rb` | 修复管理员用户数据 |
| `fix_production_database.sh` | 修复生产数据库 |
| `check_indexes.rb` | 检查数据库索引 |
| `check_capistrano_tasks.rb` | 检查 Capistrano 任务 |
| `rvm_diagnostic.sh` | RVM 环境诊断 |
| `fetch_from_server.sh` | 从服务器获取文件 |

## 使用说明

### 开发环境启动

```bash
# 最简单的启动方式
./scripts/dev/start_rails_simple.sh

# 带数据库检查的启动
./scripts/dev/start_rails_with_db.sh
```

### 部署到生产

```bash
# 推荐方式：使用 Capistrano
cap production deploy

# 或使用脚本
./scripts/deploy/deploy_production.sh
```

### 服务器初始配置

```bash
# 1. 配置 SSH
./scripts/deploy/setup_ssh_key.sh

# 2. 安装依赖
./scripts/deploy/install_dependencies.sh

# 3. 配置 systemd 服务
./scripts/deploy/setup_puma_systemd.sh
```
