#!/bin/bash

# 停止PostgreSQL测试数据库容器

set -e

echo "🛑 停止PostgreSQL测试数据库..."

# 停止并删除容器
docker compose down postgres_test

# 可选：删除数据卷（如果需要重新开始）
# docker volume rm sci2_postgres_test_data

echo "✅ PostgreSQL测试数据库已停止"