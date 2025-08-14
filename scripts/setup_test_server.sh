#!/bin/bash
# scripts/setup_test_server.sh - 测试服务器初始化脚本

set -e

SERVER_IP="8.136.10.88"
SERVER_USER="root"

echo "=== 开始初始化测试服务器 $SERVER_IP ==="

# 在远程服务器上执行初始化命令
ssh $SERVER_USER@$SERVER_IP << 'EOF'
set -e

echo "=== 更新系统 ==="
apt-get update && apt-get upgrade -y

echo "=== 安装基础软件 ==="
apt-get install -y curl git build-essential libssl-dev libreadline-dev \
  zlib1g-dev libsqlite3-dev sqlite3 libvips nginx nodejs

echo "=== 安装RVM ==="
gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys \
  409B6B1796C275462A1703113804BB82D39DC0E3 \
  7D2BAF1CF37B13E2069D6956105BD0E739499BDB

curl -sSL https://get.rvm.io | bash -s stable
source /etc/profile.d/rvm.sh

echo "=== 安装Ruby 3.4.2 ==="
rvm install 3.4.2
rvm use 3.4.2 --default

echo "=== 安装Bundler ==="
gem install bundler -v 2.5.23

echo "=== 创建部署用户 ==="
useradd -m -s /bin/bash deploy || true
mkdir -p /home/deploy/.ssh
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh

echo "=== 创建部署目录 ==="
mkdir -p /opt/sci2
chown -R deploy:deploy /opt/sci2

echo "=== 配置防火墙 ==="
ufw allow 22
ufw allow 3000
ufw allow 80
ufw allow 443
ufw --force enable

echo "=== 安装MySQL ==="
apt-get install -y mysql-server
systemctl enable mysql
systemctl start mysql

echo "=== 配置MySQL ==="
mysql -e "CREATE DATABASE IF NOT EXISTS sci2_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'sci2'@'localhost' IDENTIFIED BY 'sci2_password';"
mysql -e "GRANT ALL PRIVILEGES ON sci2_production.* TO 'sci2'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

echo "=== 服务器初始化完成 ==="
EOF

echo "=== 测试服务器初始化完成 ==="
echo "现在可以进行部署了"