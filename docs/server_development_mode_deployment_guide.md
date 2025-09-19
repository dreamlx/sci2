# 服务器部署开发模式方案

## 目标
通过在服务器上运行开发环境(development mode)实现：
1. 完全复现本地开发环境配置
2. 启用详细日志和错误堆栈显示
3. 支持热重载和实时调试

## 部署配置修改

### 步骤一：修改deploy.rb主配置
```diff:config/deploy.rb
# 设置默认部署环境为开发环境
+ set :rails_env, 'development'
lock "~> 3.19.2"
```

### 步骤二：调整环境配置
```diff:config/deploy/production.rb
# 确保开发模式配置
- set :rails_env, 'production'
+ set :rails_env, 'development'

# 保留原有服务器配置
server server_ip, user: 'test', roles: %w{app db web}
```

### 步骤三：开发环境数据库配置(关键)
```yaml:config/database.yml
development:
  adapter: sqlite3
  database: db/development.sqlite3
  pool: 5
  timeout: 5000
+  # 服务器特定数据库路径
+  database: <%= ENV['DB_PATH'] || 'db/development.sqlite3' %>
```

## 服务器端准备
1. 在Capistrano部署前创建环境变量：
```bash
export DB_PATH=/opt/sci2/shared/db/sci2_development.sqlite3
```

2. 确保数据库文件有读写权限：
```bash
sudo chmod 0666 /opt/sci2/shared/db/sci2_development.sqlite3
```

## 部署命令
```bash
USE_VPN=true DB_PATH=/opt/sci2/shared/db/sci2_development.sqlite3 bundle exec cap production deploy
```

## 还原方案(未来迁移到生产环境)
1. 恢复`deploy.rb`环境变量为`production`
2. 使用专用生产数据库
3. 重新执行生产环境资产预编译