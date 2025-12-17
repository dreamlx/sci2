# 生产环境 PostgreSQL 切换现状总结

## 背景
- 生产环境原来基于 SQLite3，已迁移到 PostgreSQL。
- 服务器 `/opt/sci2/shared/config/database.yml` 配置为 PostgreSQL。
- Capistrano 配置、部署脚本和数据库测试任务已同步更新为 PostgreSQL 逻辑。

## 当前状态 (2025-12-16 更新)
| 项目 | 状态 | 说明 |
| --- | --- | --- |
| 数据库配置 | ✅ | 服务器与仓库均使用 PostgreSQL；`db:migrate`、`database:test_connection` 在部署中已通过。 |
| Capistrano 部署 | ✅ | 代码发布、bundle、资产预编译、迁移均成功。已修复 puma:stop 任务的进程管理问题。 |
| 应用访问 | ✅ | `http://tickmytime.com/admin/login` 返回 200 OK，网站正常访问。 |
| 应用进程 | ⚠️ | Puma 通过启动脚本运行正常，但 Capistrano 自动启动存在 SSH 会话兼容性问题（见下方说明）。 |

## 已完成的修复

### 1. puma.rake 进程管理
- 修复了 `kill` 命令在进程不存在时的错误处理（添加 `|| true`）
- 防止部署因 "No such process" 错误而失败

### 2. deploy.rb 更新
- 更新 Capistrano 版本锁 (`~> 3.20.0`)
- 移除废弃的 `:scm` 设置
- 更新 SQLite3 提示为 PostgreSQL 说明
- 清理重复的 hooks（移除多余的 `puma:restart` 和无效的 `deploy:restart` 调用）
- 更新 `setup_database` 任务为 PostgreSQL 兼容

### 3. Capfile 更新
- 注释掉 `capistrano/puma` 插件（使用自定义 puma.rake）

### 4. Gemfile 更新
- 添加 Capistrano 相关 gems（capistrano, capistrano-bundler, capistrano-rails, capistrano-rvm）
- 添加 SSH 支持所需的 gems（ed25519, bcrypt_pbkdf）

### 5. production.rb 更新
- 移除废弃的 `:scm` 和 `:deploy_via` 设置

## 已知问题：Puma 自动启动

### 问题描述
Capistrano 的 `puma:start` 任务在通过 SSH 执行后台命令时存在兼容性问题：
- SSH 会话关闭后，后台进程可能被终止
- Puma 6 移除了 `-d` (daemon) 选项，需要使用其他后台化方式

### 临时解决方案
部署后手动启动 Puma：

```bash
# 方法1：执行启动脚本
ssh deploy@tickmytime.com "bash /opt/sci2/shared/tmp/start_puma.sh"

# 方法2：直接启动
ssh deploy@tickmytime.com 'cd /opt/sci2/current && RAILS_ENV=production nohup /usr/local/rvm/bin/rvm 3.4.2 do bundle exec puma -C config/puma.rb --pidfile /opt/sci2/shared/tmp/pids/puma.pid >> /opt/sci2/shared/log/puma.stdout.log 2>> /opt/sci2/shared/log/puma.stderr.log &'
```

### 推荐的永久解决方案
创建 systemd 服务来管理 Puma：

```ini
# /etc/systemd/system/puma-sci2.service
[Unit]
Description=Puma HTTP Server for sci2
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/opt/sci2/current
Environment=RAILS_ENV=production
ExecStart=/usr/local/rvm/bin/rvm 3.4.2 do bundle exec puma -C config/puma.rb
ExecStop=/bin/kill -TERM $MAINPID
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

然后启用服务：
```bash
sudo systemctl daemon-reload
sudo systemctl enable puma-sci2
sudo systemctl start puma-sci2
```

## 部署命令

```bash
# 完整部署
bundle exec cap production deploy

# 单独操作
bundle exec cap production puma:stop     # 停止 Puma
bundle exec cap production puma:status   # 查看状态
bundle exec cap production deploy:check  # 检查部署配置
```

## 验证步骤

部署完成后：

1. 检查 Puma 进程：
   ```bash
   ssh deploy@tickmytime.com "ps -ef | grep puma"
   ```

2. 检查端口绑定：
   ```bash
   ssh deploy@tickmytime.com "netstat -tuln | grep 3000"
   ```

3. 检查网站访问：
   ```bash
   curl -I http://tickmytime.com/admin/login
   ```
