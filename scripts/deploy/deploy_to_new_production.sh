#!/bin/bash
set -e

# 部署到新生产服务器 (100.98.75.43)
# 此脚本用于将应用部署到新的生产服务器

# 配置
STAGE="new_production"
SERVER="100.98.75.43"
USER="test"
DEPLOY_PATH="/opt/sci2"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 检查依赖
check_dependencies() {
    print_step "检查依赖..."

    if ! command -v bundle &> /dev/null; then
        print_error "bundle 命令未找到"
        exit 1
    fi

    if ! command -v cap &> /dev/null; then
        print_error "cap 命令未找到，请安装 Capistrano"
        exit 1
    fi

    print_info "依赖检查完成"
}

# 检查 Ruby 版本
check_ruby_version() {
    print_step "检查 Ruby 版本..."

    export RBENV_VERSION=3.4.2

    if ! rbenv versions | grep -q "3.4.2"; then
        print_error "Ruby 3.4.2 未安装"
        exit 1
    fi

    print_info "Ruby 版本: $(ruby -v)"
}

# 测试 SSH 连接
test_ssh_connection() {
    print_step "测试 SSH 连接到 ${USER}@${SERVER}..."

    if ssh -o ConnectTimeout=10 -o BatchMode=yes ${USER}@${SERVER} "echo 'SSH 连接成功'" &> /dev/null; then
        print_success "SSH 连接成功"
    else
        print_error "SSH 连接失败，请检查:"
        echo "  1. SSH 密钥是否配置正确"
        echo "  2. 服务器地址是否正确: ${SERVER}"
        echo "  3. 用户名是否正确: ${USER}"
        exit 1
    fi
}

# 检查 Git 状态
check_git_status() {
    print_step "检查 Git 状态..."

    if [ -n "$(git status --porcelain)" ]; then
        print_warning "工作目录有未提交的更改"
        git status --short
        read -p "是否继续部署？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "部署已取消"
            exit 0
        fi
    else
        print_info "工作目录干净"
    fi

    # 显示当前分支
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    print_info "当前分支: ${CURRENT_BRANCH}"
}

# 检查 Capistrano 配置
check_capistrano_config() {
    print_step "检查 Capistrano 配置..."

    if [ ! -f "config/deploy/${STAGE}.rb" ]; then
        print_error "Capistrano 配置文件不存在: config/deploy/${STAGE}.rb"
        exit 1
    fi

    print_info "Capistrano 配置文件存在"
}

# 首次部署设置
setup_first_deployment() {
    print_step "首次部署设置..."

    read -p "是否为首次部署？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "执行首次部署设置..."
        RBENV_VERSION=3.4.2 bundle exec cap ${STAGE} deploy:setup_server

        # 上传配置文件
        print_info "上传配置文件..."
        RBENV_VERSION=3.4.2 bundle exec cap ${STAGE} deploy:upload_config_files

        print_success "首次部署设置完成"
    fi
}

# 执行部署
execute_deployment() {
    print_step "执行部署..."

    print_info "开始部署到 ${STAGE} 环境..."
    RBENV_VERSION=3.4.2 bundle exec cap ${STAGE} deploy

    if [ $? -eq 0 ]; then
        print_success "部署成功完成！"
    else
        print_error "部署失败"
        exit 1
    fi
}

# 上传数据库（可选）
upload_database() {
    print_step "上传数据库..."

    read -p "是否上传本地数据库到生产服务器？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_warning "警告: 这将覆盖生产数据库！"
        read -p "确认上传？(yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            print_info "上传数据库..."
            RBENV_VERSION=3.4.2 bundle exec cap ${STAGE} deploy:upload_database
            print_success "数据库上传完成"
        else
            print_info "数据库上传已取消"
        fi
    else
        print_info "跳过数据库上传"
    fi
}

# 验证部署
verify_deployment() {
    print_step "验证部署..."

    # 检查应用是否运行
    print_info "检查应用状态..."
    ssh ${USER}@${SERVER} << EOF
        cd ${DEPLOY_PATH}/current
        RAILS_ENV=production bundle exec rails runner "puts '应用运行正常'"
EOF

    if [ $? -eq 0 ]; then
        print_success "应用运行正常"
    else
        print_error "应用运行异常"
        exit 1
    fi

    # 检查 Puma 进程
    print_info "检查 Puma 进程..."
    ssh ${USER}@${SERVER} "ps aux | grep puma | grep -v grep"

    # 检查 Nginx 状态
    print_info "检查 Nginx 状态..."
    ssh ${USER}@${SERVER} "sudo systemctl status nginx | head -n 10"
}

# 显示部署信息
show_deployment_info() {
    print_step "部署信息:"

    ssh ${USER}@${SERVER} << EOF
        echo "=== 部署路径 ==="
        ls -la ${DEPLOY_PATH}/current

        echo ""
        echo "=== 数据库信息 ==="
        cd ${DEPLOY_PATH}/current
        RAILS_ENV=production bundle exec rails runner "
          puts \"数据库: #{ActiveRecord::Base.connection.current_database}\"
          puts \"报销单数量: #{Reimbursement.count}\"
          puts \"工单数量: #{WorkOrder.count}\"
          puts \"用户数量: #{AdminUser.count}\"
        "

        echo ""
        echo "=== 应用日志 ==="
        tail -n 20 ${DEPLOY_PATH}/current/log/production.log
EOF
}

# 主流程
main() {
    echo "=========================================="
    echo "  部署到新生产服务器"
    echo "=========================================="
    echo ""
    echo "服务器: ${USER}@${SERVER}"
    echo "部署路径: ${DEPLOY_PATH}"
    echo "环境: ${STAGE}"
    echo ""

    # 检查依赖
    check_dependencies

    # 检查 Ruby 版本
    check_ruby_version

    # 测试 SSH 连接
    test_ssh_connection

    # 检查 Git 状态
    check_git_status

    # 检查 Capistrano 配置
    check_capistrano_config

    # 首次部署设置
    setup_first_deployment

    # 执行部署
    execute_deployment

    # 上传数据库（可选）
    upload_database

    # 验证部署
    verify_deployment

    # 显示部署信息
    show_deployment_info

    echo ""
    print_success "=========================================="
    print_success "  部署完成！"
    print_success "=========================================="
    echo ""
    echo "应用已部署到: ${USER}@${SERVER}"
    echo "部署路径: ${DEPLOY_PATH}"
    echo ""
    echo "访问地址: http://${SERVER}"
    echo ""
    echo "如需回滚，运行:"
    echo "  RBENV_VERSION=3.4.2 bundle exec cap ${STAGE} deploy:rollback"
}

# 执行主流程
main
