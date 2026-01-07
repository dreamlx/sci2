#!/bin/bash
# SCI2 开发环境启动脚本

# 设置数据库环境变量
export DATABASE_HOST=127.0.0.1
export DATABASE_PORT=55000
export DATABASE_USERNAME=sci2_test
export DATABASE_PASSWORD=test_password_123
export DATABASE_NAME=sci2_development
export DATABASE_NAME_TEST=sci2_test
export RAILS_ENV=development
export RAILS_MAX_THREADS=10

# 启动 Rails 服务器
echo "启动 SCI2 开发服务器..."
echo "访问地址: http://localhost:3000"
echo "Admin 登录: http://localhost:3000/admin"

RBENV_VERSION=3.4.2 bundle exec rails server -p 3000
