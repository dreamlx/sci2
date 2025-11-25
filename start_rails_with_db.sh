#!/bin/bash

# SCI2 Rails应用启动脚本
# 确保PostgreSQL容器运行并设置正确的环境变量

echo "=== SCI2 Rails应用启动脚本 ==="

# 检查Docker容器状态
echo "1. 检查PostgreSQL容器状态..."
if ! docker ps | grep -q sci2_test_db; then
    echo "   启动PostgreSQL容器..."
    docker compose up -d postgres_test
    sleep 5
else
    echo "   PostgreSQL容器已在运行"
fi

# 设置环境变量
echo "2. 设置环境变量..."
export DATABASE_HOST=localhost
export DATABASE_PORT=55000
export DATABASE_USERNAME=sci2_test
export DATABASE_PASSWORD=test_password_123
export RAILS_ENV=development
export RAILS_MAX_THREADS=10

echo "   DATABASE_HOST=$DATABASE_HOST"
echo "   DATABASE_PORT=$DATABASE_PORT"
echo "   DATABASE_USERNAME=$DATABASE_USERNAME"
echo "   RAILS_ENV=$RAILS_ENV"

# 检查数据库连接
echo "3. 检查数据库连接..."
if ruby -e "require 'socket'; Socket.tcp('$DATABASE_HOST', $DATABASE_PORT, connect_timeout: 2) { puts '✓ 数据库端口连接成功' }"; then
    echo "   数据库连接正常"
else
    echo "   ✗ 数据库连接失败"
    exit 1
fi

# 创建数据库（如果不存在）
echo "4. 确保数据库存在..."
rails db:create

# 运行迁移
echo "5. 运行数据库迁移..."
rails db:migrate

# 启动Rails服务器
echo "6. 启动Rails服务器..."
echo "   访问地址: http://localhost:3000/admin"
echo "   按 Ctrl+C 停止服务器"
echo

rails server -b 0.0.0.0 -p 3000