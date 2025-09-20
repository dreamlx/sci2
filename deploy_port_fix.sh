#!/bin/bash

# 部署端口占用问题修复脚本
# 使用方法: ./deploy_port_fix.sh

set -e

echo "=== 部署端口占用问题修复脚本 ==="
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

# 检查环境
check_environment() {
    log_info "检查部署环境..."
    
    if [ ! -f "Capfile" ]; then
        log_error "未找到 Capfile，请在项目根目录运行此脚本"
        exit 1
    fi
    
    if ! command -v bundle &> /dev/null; then
        log_error "未找到 bundle 命令，请安装 bundler"
        exit 1
    fi
    
    log_info "环境检查通过"
}

# 步骤1: 诊断远程服务器状态
diagnose_server() {
    log_info "步骤1: 诊断远程服务器状态..."
    
    echo "检查服务器基本状态..."
    USE_VPN=true bundle exec cap production server:full_diagnostic || {
        log_warn "服务器诊断失败，继续执行清理步骤"
    }
}

# 步骤2: 清理端口占用
cleanup_port() {
    log_info "步骤2: 清理端口占用..."
    
    echo "执行紧急端口清理..."
    USE_VPN=true bundle exec cap production server:emergency_cleanup || {
        log_error "端口清理失败"
        return 1
    }
    
    echo "验证端口状态..."
    USE_VPN=true bundle exec cap production server:check_port || {
        log_warn "端口检查失败，但继续执行"
    }
}

# 步骤3: 停止现有Puma进程
stop_puma() {
    log_info "步骤3: 停止现有Puma进程..."
    
    USE_VPN=true bundle exec cap production puma:stop || {
        log_warn "Puma停止失败，可能没有运行的进程"
    }
    
    # 等待进程完全停止
    sleep 5
}

# 步骤4: 验证端口释放
verify_port_free() {
    log_info "步骤4: 验证端口释放..."
    
    USE_VPN=true bundle exec cap production puma:check_port || {
        log_error "端口仍被占用，执行强制清理"
        USE_VPN=true bundle exec cap production server:emergency_cleanup
        sleep 3
    }
}

# 步骤5: 启动Puma
start_puma() {
    log_info "步骤5: 启动Puma服务器..."
    
    USE_VPN=true bundle exec cap production puma:start || {
        log_error "Puma启动失败"
        return 1
    }
    
    # 等待启动完成
    sleep 5
    
    # 验证启动状态
    USE_VPN=true bundle exec cap production puma:status || {
        log_warn "Puma状态检查失败"
    }
}

# 步骤6: 验证部署
verify_deployment() {
    log_info "步骤6: 验证部署状态..."
    
    USE_VPN=true bundle exec cap production server:check_port
    USE_VPN=true bundle exec cap production puma:status
}

# 主函数
main() {
    log_info "开始执行部署端口占用修复流程..."
    
    check_environment
    
    # 执行修复步骤
    diagnose_server
    cleanup_port
    stop_puma
    verify_port_free
    start_puma
    verify_deployment
    
    log_info "修复流程完成！"
    echo
    log_info "如果问题仍然存在，请检查以下内容："
    echo "1. 服务器上是否有其他服务占用端口3000"
    echo "2. 防火墙设置是否正确"
    echo "3. Puma配置文件是否正确"
    echo "4. Ruby/RVM环境是否正常"
    echo
    log_info "可以使用以下命令进行进一步诊断："
    echo "  USE_VPN=true bundle exec cap production server:full_diagnostic"
    echo "  USE_VPN=true bundle exec cap production puma:status"
}

# 错误处理
trap 'log_error "脚本执行失败，请检查错误信息"; exit 1' ERR

# 执行主函数
main "$@"