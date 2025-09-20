#!/bin/bash

# 紧急端口占用修复脚本 - 使用现有的 Capistrano 任务
# 使用方法: ./emergency_port_fix.sh

set -e

echo "=== 紧急端口占用修复脚本 ==="
echo "时间: $(date)"
echo

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 步骤1: 使用现有任务检查服务器状态
check_server() {
    log_info "步骤1: 检查服务器状态..."
    
    echo "检查 Puma 进程状态..."
    USE_VPN=true bundle exec cap production server:check_puma || {
        log_warn "Puma 检查失败，继续执行"
    }
}

# 步骤2: 使用增强的 Puma 任务停止服务
stop_puma() {
    log_info "步骤2: 停止 Puma 服务..."
    
    echo "使用增强的停止任务..."
    USE_VPN=true bundle exec cap production puma:stop || {
        log_warn "Puma 停止失败，可能没有运行的进程"
    }
    
    # 等待进程完全停止
    sleep 5
}

# 步骤3: 强制清理端口
force_cleanup() {
    log_info "步骤3: 强制清理端口..."
    
    echo "使用强制端口清理任务..."
    USE_VPN=true bundle exec cap production puma:force_kill_port || {
        log_error "端口清理失败"
        return 1
    }
    
    sleep 3
}

# 步骤4: 验证端口状态
verify_port() {
    log_info "步骤4: 验证端口状态..."
    
    USE_VPN=true bundle exec cap production puma:check_port || {
        log_warn "端口检查失败，但继续执行"
    }
}

# 步骤5: 启动 Puma
start_puma() {
    log_info "步骤5: 启动 Puma 服务..."
    
    USE_VPN=true bundle exec cap production puma:start || {
        log_error "Puma 启动失败"
        return 1
    }
    
    # 等待启动完成
    sleep 5
}

# 步骤6: 验证启动状态
verify_startup() {
    log_info "步骤6: 验证启动状态..."
    
    USE_VPN=true bundle exec cap production puma:status || {
        log_warn "状态检查失败"
    }
}

# 主函数
main() {
    log_info "开始执行紧急端口占用修复..."
    
    # 检查环境
    if [ ! -f "Capfile" ]; then
        log_error "未找到 Capfile，请在项目根目录运行此脚本"
        exit 1
    fi
    
    # 执行修复步骤
    check_server
    stop_puma
    force_cleanup
    verify_port
    start_puma
    verify_startup
    
    log_info "修复流程完成！"
    echo
    log_info "如果问题仍然存在，请尝试以下手动命令："
    echo "1. USE_VPN=true bundle exec cap production puma:force_kill_port"
    echo "2. USE_VPN=true bundle exec cap production puma:check_port"
    echo "3. USE_VPN=true bundle exec cap production puma:start"
    echo "4. USE_VPN=true bundle exec cap production puma:status"
}

# 错误处理
trap 'log_error "脚本执行失败，请检查错误信息"; exit 1' ERR

# 执行主函数
main "$@"