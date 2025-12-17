#!/bin/bash

# 统一部署脚本
# 使用方法: ./deployment/deploy.sh [环境名] [选项]
# 示例: ./deployment/deploy.sh production --fix-port --migrate

set -e

# 配置
ENVIRONMENT=${1:-production}
EXTRA_ARGS=${@:2}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="deployment/deploy_${ENVIRONMENT}_${TIMESTAMP}.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a $LOG_FILE
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a $LOG_FILE
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a $LOG_FILE
}

# 检查环境
check_environment() {
    log "检查部署环境: $ENVIRONMENT"

    if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "staging" ]]; then
        error "不支持的部署环境: $ENVIRONMENT"
        error "支持的环境: production, staging"
        exit 1
    fi

    # 检查必要的服务器连接
    if ! ssh -o ConnectTimeout=10 deploy@your-server.com "echo '服务器连接正常'" 2>/dev/null; then
        error "无法连接到服务器，请检查网络和SSH配置"
        exit 1
    fi

    log "环境检查通过"
}

# 数据库备份
backup_database() {
    log "开始数据库备份..."
    ssh deploy@your-server.com "cd /var/www/sci2 && backup_database.sh" || {
        error "数据库备份失败"
        exit 1
    }
    log "数据库备份完成"
}

# 部署应用
deploy_application() {
    log "开始部署应用到 $ENVIRONMENT 环境..."

    # 使用 Capistrano 部署
 if [[ "$ENVIRONMENT" == "production" ]]; then
        cap production deploy --trace 2>&1 | tee -a $LOG_FILE
    else
        cap staging deploy --trace 2>&1 | tee -a $LOG_FILE
    fi

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        error "应用部署失败"
        exit 1
    fi
    log "应用部署完成"
}

# 后处理任务
post_deploy_tasks() {
    log "执行部署后任务..."

    # 检查是否需要迁移数据库
    if [[ "$EXTRA_ARGS" == *"--migrate"* ]]; then
        log "执行数据库迁移..."
        ssh deploy@your-server.com "cd /var/www/sci2/current && bundle exec rails db:migrate RAILS_ENV=$ENVIRONMENT"
    fi

    # 检查是否需要修复端口
    if [[ "$EXTRA_ARGS" == *"--fix-port"* ]]; then
        log "执行端口修复..."
        ssh deploy@your-server.com "sudo ./deployment/emergency_port_fix.sh"
    fi

    # 重启服务
    log "重启应用服务..."
    ssh deploy@your-server.com "sudo systemctl reload nginx"
    ssh deploy@your-server.com "sudo systemctl restart puma"

    log "部署后任务完成"
}

# 健康检查
health_check() {
    log "执行健康检查..."

    # 检查应用是否正常响应
    local url=""
    if [[ "$ENVIRONMENT" == "production" ]]; then
        url="https://your-production-domain.com"
    else
        url="https://your-staging-domain.com"
    fi

    if curl -f -s -o /dev/null "$url/health"; then
        log "健康检查通过"
    else
        error "健康检查失败"
        exit 1
    fi
}

# 主部署流程
main() {
    log "开始部署流程 - 环境: $ENVIRONMENT"
    log "额外参数: $EXTRA_ARGS"

    check_environment
    backup_database
    deploy_application
    post_deploy_tasks
    health_check

    log "部署完成！"
    log "部署日志: $LOG_FILE"
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [环境名] [选项]"
    echo ""
    echo "环境名:"
    echo "  production  - 生产环境（默认）"
    echo "  staging     - 测试环境"
    echo ""
    echo "选项:"
    echo "  --migrate   - 执行数据库迁移"
    echo "  --fix-port  - 修复端口配置"
    echo "  --help      - 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 production"
    echo "  $0 staging --migrate"
    echo "  $0 production --migrate --fix-port"
}

# 解析参数
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# 执行主流程
main