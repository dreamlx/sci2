#!/bin/bash

# 新生产服务器环境准备脚本
# 在新服务器上执行: ssh root@tickmytime.com "bash -s" < deployment/server_setup.sh

set -e

echo "=== 开始新服务器环境准备 ==="

# 系统更新
echo "1. 更新系统..."
apt update && apt upgrade -y

# 安装基础工具
echo "2. 安装基础工具..."
apt install -y curl wget git build-essential libssl-dev libreadline-dev zlib1g-dev \
    postgresql-contrib postgresql-client nginx certbot python3-certbot-nginx

# 创建应用用户
echo "3. 创建deploy用户..."
if ! id "deploy" &>/dev/null; then
    useradd -m -s /bin/bash deploy
    usermod -aG sudo deploy
    echo "deploy用户创建成功"
else
    echo "deploy用户已存在"
fi

# PostgreSQL配置
echo "4. 配置PostgreSQL..."
sudo -u postgres psql << EOF
CREATE USER sci2_prod WITH PASSWORD 'your_secure_password';
CREATE DATABASE sci2_production OWNER sci2_prod;
GRANT ALL PRIVILEGES ON DATABASE sci2_production TO sci2_prod;
\q
EOF

# 配置PostgreSQL允许本地连接
echo "5. 配置PostgreSQL连接权限..."
echo "host    sci2_production    sci2_prod    127.0.0.1/32    md5" >> /etc/postgresql/15/main/pg_hba.conf
echo "host    sci2_production    sci2_prod    localhost       md5" >> /etc/postgresql/15/main/pg_hba.conf

# 重启PostgreSQL
echo "6. 重启PostgreSQL..."
systemctl restart postgresql
systemctl enable postgresql

# RVM和Ruby安装
echo "7. 安装RVM和Ruby..."
sudo -u deploy bash << 'EOF'
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
EOF

# Node.js安装
echo "8. 安装Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

# 验证Node.js安装
node --version
npm --version

# 创建部署目录
echo "9. 创建部署目录..."
mkdir -p /opt/sci2
chown deploy:deploy /opt/sci2

echo "=== 服务器环境准备完成 ==="
echo "请确保SSH密钥已配置，然后可以开始部署应用"