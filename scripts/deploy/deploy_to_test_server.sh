#!/bin/bash
# scripts/deploy_to_test_server.sh - 部署到测试服务器

set -e

SERVER_IP="8.136.10.88"
SERVER_USER="root"
DEPLOY_USER="deploy"
DEPLOY_PATH="/opt/sci2"

echo "=== 开始部署到测试服务器 $SERVER_IP ==="

# 在远程服务器上执行部署命令
ssh $SERVER_USER@$SERVER_IP << 'EOF'
set -e

echo "=== 切换到部署用户 ==="
su - deploy << 'DEPLOY_SCRIPT'
set -e

echo "=== 进入部署目录 ==="
cd /opt/sci2

echo "=== 检查Git仓库 ==="
if [ ! -d ".git" ]; then
  echo "初始化Git仓库..."
  git init
  git remote add origin https://github.com/your-repo/sci2.git
fi

echo "=== 拉取最新代码 ==="
git fetch origin
git checkout main
git pull origin main

echo "=== 安装Ruby依赖 ==="
source /etc/profile.d/rvm.sh
bundle install --without development test --deployment

echo "=== 配置数据库为SQLite ==="
cat > config/database.yml << 'DATABASE_CONFIG'
production:
  adapter: sqlite3
  database: db/sci2_production.sqlite3
  pool: 5
  timeout: 5000
DATABASE_CONFIG

echo "=== 预编译资产 ==="
SECRET_KEY_BASE=$(bundle exec rails secret)
export SECRET_KEY_BASE=$SECRET_KEY_BASE
export RAILS_ENV=production
bundle exec rails assets:precompile

echo "=== 创建数据库 ==="
bundle exec rails db:create
bundle exec rails db:migrate
bundle exec rails db:seed

echo "=== 启动服务 ==="
# 使用Puma启动服务
bundle exec puma -e production -d -b tcp://0.0.0.0:3000

echo "=== 部署完成 ==="
DEPLOY_SCRIPT

echo "=== 配置Nginx反向代理 ==="
cat > /etc/nginx/sites-available/sci2 << 'NGINX_CONFIG'
server {
  listen 80;
  server_name _;

  root /opt/sci2/public;
  try_files $uri/index.html $uri @puma;

  location @puma {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Host $http_host;
    proxy_redirect off;
    proxy_pass http://127.0.0.1:3000;
  }

  client_max_body_size 100M;
  keepalive_timeout 10;
}
NGINX_CONFIG

echo "=== 启用Nginx配置 ==="
ln -sf /etc/nginx/sites-available/sci2 /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo "=== 重启Nginx ==="
systemctl restart nginx

echo "=== 检查服务状态 ==="
systemctl status nginx
ps aux | grep puma

echo "=== 部署完成！访问地址: http://$SERVER_IP ==="
EOF

echo "=== 部署脚本执行完成 ==="