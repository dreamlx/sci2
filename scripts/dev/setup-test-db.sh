#!/bin/bash

# PostgreSQL测试数据库设置脚本
# 自动启动Docker容器并配置测试环境

set -e

echo "🚀 开始设置PostgreSQL测试数据库..."

# 检查Docker是否运行
if ! docker info > /dev/null 2>&1; then
  echo "❌ Docker未运行，请先启动Docker"
  exit 1
fi

# 获取随机端口映射
echo "📋 启动PostgreSQL容器..."
docker compose up -d postgres_test

# 等待容器启动
echo "⏳ 等待PostgreSQL启动..."
sleep 5

# 获取映射的端口
MAPPED_PORT=$(docker port sci2_test_db 5432 | cut -d: -f2)
echo "🔗 PostgreSQL端口映射: localhost:${MAPPED_PORT}"

# 更新.env.test文件中的端口
sed -i.bak "s/DATABASE_PORT=.*/DATABASE_PORT=${MAPPED_PORT}/" .env.test

# 等待数据库就绪
echo "🔍 检查数据库连接..."
until docker exec sci2_test_db pg_isready -U sci2_test -d sci2_test > /dev/null 2>&1; do
  echo "⏳ 等待数据库启动..."
  sleep 2
done

echo "✅ PostgreSQL数据库已就绪！"

# 安装PostgreSQL依赖
echo "📦 安装PostgreSQL依赖..."
bundle install

# 创建测试数据库
echo "🗄️ 创建测试数据库..."
RAILS_ENV=test bundle exec rails db:create

# 运行数据库迁移
echo "🔄 运行数据库迁移..."
RAILS_ENV=test bundle exec rails db:migrate

echo "🎉 测试数据库设置完成！"
echo "📝 数据库连接信息:"
echo "   Host: localhost"
echo "   Port: ${MAPPED_PORT}"
echo "   Database: sci2_test"
echo "   Username: sci2_test"
echo "   Password: test_password_123"