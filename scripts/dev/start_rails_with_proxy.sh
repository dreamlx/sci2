#!/bin/bash

# SCI2 代理环境启动脚本
# 适用于中国大陆网络环境

set -e

echo "🚀 启动 SCI2 应用 (代理模式)..."

# 检查 Docker 和 Docker Compose 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

# 检查 Docker Compose 版本并设置命令
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "❌ Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi

echo "✅ 使用 Docker Compose 命令: $DOCKER_COMPOSE"

# 检查代理设置
PROXY_PORT=${PROXY_PORT:-7890}
HTTP_PROXY="http://host.docker.internal:$PROXY_PORT"
HTTPS_PROXY="http://host.docker.internal:$PROXY_PORT"
NO_PROXY="localhost,127.0.0.1,host.docker.internal"

echo "🔧 代理设置:"
echo "   HTTP_PROXY: $HTTP_PROXY"
echo "   HTTPS_PROXY: $HTTPS_PROXY"
echo "   NO_PROXY: $NO_PROXY"

# 创建环境变量文件（如果不存在）
if [ ! -f .env ]; then
    echo "📝 创建 .env 文件..."
    cp .env.example .env
    echo "⚠️  请编辑 .env 文件设置你的配置"
fi

# 创建必要的目录
echo "📁 创建必要的目录..."
mkdir -p docker/postgres/init
mkdir -p log tmp storage

# 停止并清理旧的容器（如果存在）
echo "🧹 清理旧的容器..."
$DOCKER_COMPOSE -f docker-compose.proxy.yml down --remove-orphans 2>/dev/null || true

# 设置代理环境变量
export HTTP_PROXY="$HTTP_PROXY"
export HTTPS_PROXY="$HTTPS_PROXY"
export NO_PROXY="$NO_PROXY"

# 构建并启动服务
echo "🔨 构建 Docker 镜像 (使用代理)..."
$DOCKER_COMPOSE -f docker-compose.proxy.yml build --no-cache

echo "🚀 启动服务..."
$DOCKER_COMPOSE -f docker-compose.proxy.yml up -d

# 等待数据库就绪
echo "⏳ 等待数据库就绪..."
sleep 10

# 检查数据库连接
echo "🔍 检查数据库连接..."
for i in {1..30}; do
    if $DOCKER_COMPOSE -f docker-compose.proxy.yml exec -T db pg_isready -U sci2 -d sci2_development > /dev/null 2>&1; then
        echo "✅ 数据库已就绪"
        break
    fi
    echo "⏳ 等待数据库启动... ($i/30)"
    sleep 2
done

# 运行数据库迁移
echo "🗃️  运行数据库迁移..."
$DOCKER_COMPOSE -f docker-compose.proxy.yml exec -T app bundle exec rails db:create db:migrate db:seed

# 创建管理员用户（如果不存在）
echo "👤 创建管理员用户..."
$DOCKER_COMPOSE -f docker-compose.proxy.yml exec -T app bundle exec rails runner "
admin = AdminUser.find_or_create_by(email: 'admin@sci2.local') do |user|
  user.password = 'admin123'
  user.password_confirmation = 'admin123'
  user.active = true
end
puts '管理员用户已创建: admin@sci2.local / admin123'
"

echo ""
echo "🎉 SCI2 应用启动完成！"
echo ""
echo "📍 访问地址:"
echo "   本地: http://localhost:3000"
echo "   服务器: http://你的服务器IP:3000"
echo ""
echo "🔑 默认管理员账户:"
echo "   邮箱: admin@sci2.local"
echo "   密码: admin123"
echo ""
echo "📋 常用命令:"
echo "   查看日志: $DOCKER_COMPOSE -f docker-compose.proxy.yml logs -f app"
echo "   停止服务: $DOCKER_COMPOSE -f docker-compose.proxy.yml down"
echo "   重启服务: $DOCKER_COMPOSE -f docker-compose.proxy.yml restart"
echo "   进入容器: $DOCKER_COMPOSE -f docker-compose.proxy.yml exec app bash"
echo ""
echo "⚠️  首次启动后请立即修改默认密码！"
echo ""
echo "🔧 代理配置说明:"
echo "   - 确保你的代理服务运行在端口 $PROXY_PORT"
echo "   - 如果使用不同端口，请设置: PROXY_PORT=你的端口 $0"
echo "   - 代理地址: http://host.docker.internal:$PROXY_PORT"