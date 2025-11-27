# 新生产服务器部署方案 (PostgreSQL直接安装版)

## 方案概述

基于用户确认，采用**方案C: PostgreSQL直接安装**，在新机器上实现最佳性能的标准化生产部署。

## 架构设计

### 最终架构
- **部署工具**: Capistrano 3.19.2
- **Ruby版本**: 3.4.2 (RVM管理)
- **应用服务器**: Puma (多进程多线程)
- **数据库**: PostgreSQL 15 (直接安装)
- **部署目录**: `/opt/sci2`
- **应用端口**: 3000
- **数据库端口**: 5432

### 优势分析
- **最佳性能**: 无Docker开销，直接系统调用
- **资源高效**: 内存和CPU使用更优
- **成熟稳定**: 生产环境验证过的方案
- **维护简单**: 传统运维方式，团队熟悉

## 详细实施计划

### 第一阶段：新服务器环境准备

#### 1.1 系统基础配置

```bash
# 连接到新服务器
ssh root@tickmytime.com

# 系统更新
apt update && apt upgrade -y

# 安装基础工具
apt install -y curl wget git build-essential libssl-dev libreadline-dev zlib1g-dev \
    postgresql-contrib postgresql-client nginx certbot python3-certbot-nginx

# 创建应用用户
useradd -m -s /bin/bash deploy
usermod -aG sudo deploy
```

#### 1.2 PostgreSQL安装和配置

```bash
# 切换到postgres用户
sudo -u postgres psql

# 在psql中执行：
CREATE USER sci2_prod WITH PASSWORD 'your_secure_password';
CREATE DATABASE sci2_production OWNER sci2_prod;
GRANT ALL PRIVILEGES ON DATABASE sci2_production TO sci2_prod;
\q

# 配置PostgreSQL允许本地连接
echo "host    sci2_production    sci2_prod    127.0.0.1/32    md5" >> /etc/postgresql/15/main/pg_hba.conf
echo "host    sci2_production    sci2_prod    localhost       md5" >> /etc/postgresql/15/main/pg_hba.conf

# 重启PostgreSQL
systemctl restart postgresql
systemctl enable postgresql
```

#### 1.3 RVM和Ruby安装

```bash
# 切换到deploy用户
su - deploy

# 安装RVM
gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm

# 安装Ruby 3.4.2
rvm install 3.4.2
rvm use 3.4.2 --default

# 验证安装
ruby --version
gem --version
```

#### 1.4 Node.js安装

```bash
# 安装Node.js 18 (用于资产编译)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 验证安装
node --version
npm --version
```

### 第二阶段：应用部署配置

#### 2.1 Capistrano配置更新

更新 `config/deploy/production.rb`:

```ruby
# 新服务器配置
server 'tickmytime.com', user: 'deploy', roles: %w[app db web]

# 生产环境设置
set :stage, :production
set :rails_env, 'production'
set :branch, 'main'

# 使用HTTPS仓库
set :repo_url, 'https://gitee.com/dreamlx/sci2.git'
set :scm, :git
set :deploy_via, :remote_cache

# SSH配置 - 使用密钥认证
set :ssh_options, {
  keys: %w(~/.ssh/id_rsa),
  forward_agent: true,
  auth_methods: %w(publickey),
  verify_host_key: :never
}

# PostgreSQL配置
set :database_config, 'config/database.production.yml'

# 环境变量
set :env_variables, {
  'RAILS_ENV' => 'production',
  'DATABASE_HOST' => 'localhost',
  'DATABASE_PORT' => '5432',
  'DATABASE_USERNAME' => 'sci2_prod',
  'DATABASE_PASSWORD' => 'your_secure_password',
  'RAILS_MAX_THREADS' => '20'
}

# 保守的生产环境设置
set :keep_releases, 5
set :puma_workers, 4
set :puma_threads, [8, 32]
```

#### 2.2 数据库配置文件

创建 `config/database.production.yml`:

```yaml
production:
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 20 } %>
  username: <%= ENV.fetch("DATABASE_USERNAME") %>
  password: <%= ENV.fetch("DATABASE_PASSWORD") %>
  host: <%= ENV.fetch("DATABASE_HOST") { "localhost" } %>
  port: <%= ENV.fetch("DATABASE_PORT") { "5432" } %>
  database: sci2_production
  reconnect: true
  checkout_timeout: 5
  variables:
    statement_timeout: 30s
    lock_timeout: 10s
```

#### 2.3 环境变量文件

创建 `.env.production`:

```bash
RAILS_ENV=production
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USERNAME=sci2_prod
DATABASE_PASSWORD=your_secure_password
RAILS_MAX_THREADS=20
SECRET_KEY_BASE=your_secret_key_base
```

### 第三阶段：部署执行

#### 3.1 首次部署

```bash
# 在本地开发机器上执行
cd /path/to/your/sci2/project

# 检查部署配置
cap production deploy:check

# 执行首次部署
cap production deploy

# 运行数据库迁移
cap production deploy:migrate

# 预编译资产
cap production deploy:assets:precompile

# 重启应用
cap production puma:restart
```

#### 3.2 Nginx配置

在服务器上创建 `/etc/nginx/sites-available/sci2`:

```nginx
server {
    listen 80;
    server_name tickmytime.com;
    
    # 重定向到HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name tickmytime.com;
    
    ssl_certificate /etc/letsencrypt/live/tickmytime.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/tickmytime.com/privkey.pem;
    
    # SSL配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # 应用配置
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30;
        proxy_send_timeout 30;
        proxy_read_timeout 30;
    }
    
    # 静态文件
    location /assets/ {
        alias /opt/sci2/current/public/assets/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # 上传文件
    location /uploads/ {
        alias /opt/sci2/current/public/uploads/;
        expires 1y;
    }
}
```

启用站点：

```bash
sudo ln -s /etc/nginx/sites-available/sci2 /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

#### 3.3 SSL证书配置

```bash
# 获取SSL证书
sudo certbot --nginx -d tickmytime.com

# 设置自动续期
sudo crontab -e
# 添加以下行：
0 12 * * * /usr/bin/certbot renew --quiet
```

### 第四阶段：监控和维护

#### 4.1 日志配置

创建日志轮转配置 `/etc/logrotate.d/sci2`:

```
/opt/sci2/current/log/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    copytruncate
    su deploy deploy
}
```

#### 4.2 数据库备份脚本

创建 `/opt/sci2/scripts/backup_db.sh`:

```bash
#!/bin/bash

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/sci2/backups"
DB_NAME="sci2_production"
DB_USER="sci2_prod"

# 创建备份目录
mkdir -p $BACKUP_DIR

# 数据库备份
pg_dump -U $DB_USER -h localhost $DB_NAME > $BACKUP_DIR/db_backup_$DATE.sql

# 压缩备份
gzip $BACKUP_DIR/db_backup_$DATE.sql

# 删除7天前的备份
find $BACKUP_DIR -name "db_backup_*.sql.gz" -mtime +7 -delete

echo "数据库备份完成: db_backup_$DATE.sql.gz"
```

设置执行权限并添加到crontab：

```bash
chmod +x /opt/sci2/scripts/backup_db.sh

# 添加到crontab (每天凌晨2点备份)
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/sci2/scripts/backup_db.sh") | crontab -
```

#### 4.3 系统监控脚本

创建 `/opt/sci2/scripts/health_check.sh`:

```bash
#!/bin/bash

# 检查应用状态
check_app() {
    if curl -f -s http://localhost:3000/health > /dev/null; then
        echo "✓ 应用运行正常"
        return 0
    else
        echo "✗ 应用无响应"
        return 1
    fi
}

# 检查数据库连接
check_database() {
    if sudo -u postgres psql -U sci2_prod -d sci2_production -c "SELECT 1;" > /dev/null 2>&1; then
        echo "✓ 数据库连接正常"
        return 0
    else
        echo "✗ 数据库连接失败"
        return 1
    fi
}

# 检查磁盘空间
check_disk() {
    DISK_USAGE=$(df /opt/sci2 | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ $DISK_USAGE -lt 80 ]; then
        echo "✓ 磁盘空间充足 ($DISK_USAGE%)"
        return 0
    else
        echo "✗ 磁盘空间不足 ($DISK_USAGE%)"
        return 1
    fi
}

# 执行所有检查
echo "=== 系统健康检查 $(date) ==="
check_app
check_database
check_disk
echo "=== 检查完成 ==="
```

### 第五阶段：性能优化

#### 5.1 PostgreSQL优化

编辑 `/etc/postgresql/15/main/postgresql.conf`:

```ini
# 内存设置
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB

# 连接设置
max_connections = 100

# WAL设置
wal_level = replica
max_wal_size = 1GB
min_wal_size = 80MB

# 性能设置
random_page_cost = 1.1
effective_io_concurrency = 200
```

重启PostgreSQL：

```bash
sudo systemctl restart postgresql
```

#### 5.2 Puma优化

更新 `config/puma.rb`:

```ruby
# Puma配置
workers 4
threads 8, 32

bind "tcp://127.0.0.1:3000"
environment "production"
daemonize false

# 预加载应用
preload_app!

# 工作进程超时
worker_timeout 30

# 内存清理
on_worker_boot do
  ActiveSupport::DescendantsTracker.clear_all
  ActiveSupport::Reloader.clear!
end
```

## 部署验证清单

### 部署前检查
- [ ] 新服务器网络连通性
- [ ] SSH密钥配置
- [ ] 域名DNS解析
- [ ] SSL证书准备

### 部署过程检查
- [ ] 系统依赖安装完成
- [ ] PostgreSQL安装并配置
- [ ] Ruby和RVM安装成功
- [ ] Capistrano部署成功
- [ ] 数据库迁移完成
- [ ] Nginx配置正确

### 部署后验证
- [ ] 应用可以正常访问
- [ ] 数据库连接正常
- [ ] SSL证书有效
- [ ] 日志记录正常
- [ ] 备份脚本工作
- [ ] 监控脚本运行

## 故障排除指南

### 常见问题

1. **PostgreSQL连接失败**
   ```bash
   # 检查服务状态
   sudo systemctl status postgresql
   
   # 检查配置文件
   sudo -u postgres psql -c "SELECT version();"
   
   # 检查网络连接
   netstat -tlnp | grep 5432
   ```

2. **Ruby版本问题**
   ```bash
   # 检查RVM安装
   rvm --version
   
   # 重新安装Ruby
   rvm reinstall 3.4.2
   
   # 检查gem安装
   gem list bundler
   ```

3. **Nginx配置问题**
   ```bash
   # 测试配置
   sudo nginx -t
   
   # 查看错误日志
   sudo tail -f /var/log/nginx/error.log
   ```

## 总结

**方案C优势**:
- ✅ 最佳性能表现
- ✅ 资源利用高效
- ✅ 运维团队熟悉
- ✅ 故障排除简单

**置信度评级**: 5/5

这个方案充分利用了新机器的优势，提供了生产级别的性能和稳定性，同时保持了运维的简洁性。