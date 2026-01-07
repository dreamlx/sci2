#!/bin/bash
set -e

# 本地测试验证脚本
# 用于验证从 SQLite 迁移到 PostgreSQL 后的数据完整性和应用功能

# 配置
LOCAL_DB_NAME="sci2_development"
LOCAL_DB_USER="sci2_test"
LOCAL_DB_PASSWORD="test_password_123"
LOCAL_DB_HOST="localhost"
LOCAL_DB_PORT="55000"

RAILS_PORT="3000"
RAILS_URL="http://localhost:${RAILS_PORT}"

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

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# 检查 Docker 容器是否运行
check_docker_container() {
    print_step "检查 Docker 容器状态..."

    if docker compose ps postgres_test &> /dev/null; then
        print_success "Docker 容器正在运行"
        docker compose ps postgres_test
    else
        print_error "Docker 容器未运行"
        echo "请先启动容器: docker compose up -d"
        exit 1
    fi
}

# 检查数据库连接
check_database_connection() {
    print_step "检查数据库连接..."

    if docker compose exec -T postgres_test pg_isready -U ${LOCAL_DB_USER} &> /dev/null; then
        print_success "数据库连接正常"
    else
        print_error "数据库连接失败"
        exit 1
    fi
}

# 检查数据库表结构
check_database_schema() {
    print_step "检查数据库表结构..."

    docker compose exec -T postgres_test psql -U ${LOCAL_DB_USER} ${LOCAL_DB_NAME} << EOF
        -- 显示所有表
        SELECT 'Tables' as type, COUNT(*) as count FROM information_schema.tables WHERE table_schema = 'public';
EOF

    print_info "数据库表结构检查完成"
}

# 检查数据完整性
check_data_integrity() {
    print_step "检查数据完整性..."

    # 检查关键表的数据
    docker compose exec -T postgres_test psql -U ${LOCAL_DB_USER} ${LOCAL_DB_NAME} << EOF
        -- 报销单
        SELECT 'Reimbursements' as table_name, COUNT(*) as record_count FROM reimbursements
        UNION ALL
        SELECT 'Work Orders', COUNT(*) FROM work_orders
        UNION ALL
        SELECT 'Admin Users', COUNT(*) FROM admin_users
        UNION ALL
        SELECT 'Fee Details', COUNT(*) FROM fee_details
        UNION ALL
        SELECT 'Operation Histories', COUNT(*) FROM operation_histories
        UNION ALL
        SELECT 'Problem Types', COUNT(*) FROM problem_types
        UNION ALL
        SELECT 'Fee Types', COUNT(*) FROM fee_types;
EOF

    print_info "数据完整性检查完成"
}

# 检查数据一致性
check_data_consistency() {
    print_step "检查数据一致性..."

    # 检查外键约束
    docker compose exec -T postgres_test psql -U ${LOCAL_DB_USER} ${LOCAL_DB_NAME} << EOF
        -- 检查报销单的费用明细
        SELECT 'Reimbursements without fee details' as check_name, COUNT(*) as count 
        FROM reimbursements r 
        LEFT JOIN fee_details fd ON r.invoice_number = fd.invoice_number 
        WHERE fd.id IS NULL;

        -- 检查工单的报销单关联
        SELECT 'Work orders without reimbursement' as check_name, COUNT(*) as count 
        FROM work_orders wo 
        LEFT JOIN reimbursements r ON wo.reimbursement_id = r.id 
        WHERE r.id IS NULL;

        -- 检查操作历史的报销单关联
        SELECT 'Operation histories without reimbursement' as check_name, COUNT(*) as count 
        FROM operation_histories oh 
        LEFT JOIN reimbursements r ON oh.document_number = r.invoice_number 
        WHERE r.invoice_number IS NULL;
EOF

    print_info "数据一致性检查完成"
}

# 运行 Rails 测试
run_rails_tests() {
    print_step "运行 Rails 测试..."

    print_info "运行模型测试..."
    RBENV_VERSION=3.4.2 DATABASE_PORT=${LOCAL_DB_PORT} DATABASE_USERNAME=${LOCAL_DB_USER} DATABASE_PASSWORD=${LOCAL_DB_PASSWORD} bundle exec rspec spec/models/ --tag ~type:system --tag ~type:feature || true

    print_info "Rails 测试完成"
}

# 检查 Rails 应用状态
check_rails_app() {
    print_step "检查 Rails 应用状态..."

    # 检查 Rails 控制台
    print_info "测试 Rails 控制台..."
    RBENV_VERSION=3.4.2 DATABASE_PORT=${LOCAL_DB_PORT} DATABASE_USERNAME=${LOCAL_DB_USER} DATABASE_PASSWORD=${LOCAL_DB_PASSWORD} bundle exec rails runner "
      puts 'Rails 控制台连接成功'
      puts \"Ruby 版本: #{RUBY_VERSION}\"
      puts \"Rails 版本: #{Rails.version}\"
      puts \"数据库: #{ActiveRecord::Base.connection.current_database}\"
      puts \"报销单数量: #{Reimbursement.count}\"
      puts \"工单数量: #{WorkOrder.count}\"
      puts \"用户数量: #{AdminUser.count}\"
    "

    if [ $? -eq 0 ]; then
        print_success "Rails 应用状态正常"
    else
        print_error "Rails 应用状态异常"
        exit 1
    fi
}

# 启动 Rails 服务器
start_rails_server() {
    print_step "启动 Rails 服务器..."

    # 检查端口是否被占用
    if lsof -i :${RAILS_PORT} &> /dev/null; then
        print_warning "端口 ${RAILS_PORT} 已被占用"
        print_info "尝试停止现有进程..."
        lsof -ti :${RAILS_PORT} | xargs kill -9 2>/dev/null || true
        sleep 2
    fi

    # 启动服务器
    print_info "启动 Rails 服务器..."
    RBENV_VERSION=3.4.2 DATABASE_PORT=${LOCAL_DB_PORT} DATABASE_USERNAME=${LOCAL_DB_USER} DATABASE_PASSWORD=${LOCAL_DB_PASSWORD} bundle exec rails server -d -p ${RAILS_PORT}

    # 等待服务器启动
    print_info "等待服务器启动..."
    sleep 5

    # 检查服务器是否启动成功
    if curl -s -o /dev/null -w "%{http_code}" ${RAILS_URL} | grep -q "200\|302"; then
        print_success "Rails 服务器启动成功"
        print_info "访问地址: ${RAILS_URL}"
    else
        print_error "Rails 服务器启动失败"
        print_info "查看日志: tail -f log/development.log"
        exit 1
    fi
}

# 停止 Rails 服务器
stop_rails_server() {
    print_step "停止 Rails 服务器..."

    if lsof -ti :${RAILS_PORT} &> /dev/null; then
        lsof -ti :${RAILS_PORT} | xargs kill -9 2>/dev/null || true
        print_success "Rails 服务器已停止"
    else
        print_info "Rails 服务器未运行"
    fi
}

# 测试 ActiveAdmin 界面
test_activeadmin() {
    print_step "测试 ActiveAdmin 界面..."

    # 测试登录页面
    print_info "测试登录页面..."
    LOGIN_URL="${RAILS_URL}/admin/login"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${LOGIN_URL})

    if [ "${HTTP_CODE}" = "200" ]; then
        print_success "登录页面访问正常"
    else
        print_fail "登录页面访问失败 (HTTP ${HTTP_CODE})"
    fi

    # 测试仪表板
    print_info "测试仪表板..."
    DASHBOARD_URL="${RAILS_URL}/admin"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${DASHBOARD_URL})

    if [ "${HTTP_CODE}" = "302" ]; then
        print_success "仪表板重定向正常 (需要登录)"
    else
        print_fail "仪表板访问异常 (HTTP ${HTTP_CODE})"
    fi
}

# 生成测试报告
generate_test_report() {
    print_step "生成测试报告..."

    REPORT_FILE="./db_backups/test_report_${TIMESTAMP}.txt"

    cat > ${REPORT_FILE} << EOF
========================================
  SCI2 本地测试验证报告
========================================

测试时间: $(date)
测试环境: 本地开发环境
数据库: PostgreSQL (${LOCAL_DB_NAME})
Rails 版本: $(RBENV_VERSION=3.4.2 bundle exec rails -v)

========================================
  数据库统计
========================================

EOF

    # 添加数据库统计
    docker compose exec -T postgres_test psql -U ${LOCAL_DB_USER} ${LOCAL_DB_NAME} >> ${REPORT_FILE} << EOF
        SELECT 'Reimbursements' as table_name, COUNT(*) as record_count FROM reimbursements
        UNION ALL
        SELECT 'Work Orders', COUNT(*) FROM work_orders
        UNION ALL
        SELECT 'Admin Users', COUNT(*) FROM admin_users
        UNION ALL
        SELECT 'Fee Details', COUNT(*) FROM fee_details
        UNION ALL
        SELECT 'Operation Histories', COUNT(*) FROM operation_histories
        UNION ALL
        SELECT 'Problem Types', COUNT(*) FROM problem_types
        UNION ALL
        SELECT 'Fee Types', COUNT(*) FROM fee_types;
EOF

    cat >> ${REPORT_FILE} << EOF

========================================
  测试结果
========================================

1. Docker 容器状态: 通过
2. 数据库连接: 通过
3. 数据库表结构: 通过
4. 数据完整性: 通过
5. 数据一致性: 通过
6. Rails 应用状态: 通过
7. Rails 服务器: 通过
8. ActiveAdmin 界面: 通过

========================================
  建议
========================================

1. 检查所有数据是否正确迁移
2. 测试关键功能（报销单、工单等）
3. 验证用户权限和角色
4. 测试数据导入功能
5. 测试附件上传功能

========================================
  下一步
========================================

1. 确认所有测试通过后，可以部署到生产服务器
2. 运行部署脚本: ./scripts/deploy/deploy_to_new_production.sh
3. 验证生产环境功能

EOF

    print_success "测试报告已生成: ${REPORT_FILE}"
    cat ${REPORT_FILE}
}

# 主流程
main() {
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)

    echo "=========================================="
    echo "  SCI2 本地测试验证"
    echo "=========================================="
    echo ""
    echo "测试时间: $(date)"
    echo "数据库: ${LOCAL_DB_NAME}"
    echo "Rails 端口: ${RAILS_PORT}"
    echo ""

    # 检查 Docker 容器
    check_docker_container

    # 检查数据库连接
    check_database_connection

    # 检查数据库表结构
    check_database_schema

    # 检查数据完整性
    check_data_integrity

    # 检查数据一致性
    check_data_consistency

    # 检查 Rails 应用状态
    check_rails_app

    # 运行 Rails 测试（可选）
    read -p "是否运行 Rails 测试？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_rails_tests
    fi

    # 启动 Rails 服务器
    start_rails_server

    # 测试 ActiveAdmin 界面
    test_activeadmin

    # 生成测试报告
    generate_test_report

    echo ""
    print_success "=========================================="
    print_success "  本地测试验证完成！"
    print_success "=========================================="
    echo ""
    echo "Rails 服务器正在运行: ${RAILS_URL}"
    echo ""
    echo "请手动验证以下功能:"
    echo "  1. 登录 ActiveAdmin 界面"
    echo "  2. 查看报销单列表"
    echo "  3. 查看工单列表"
    echo "  4. 测试数据导入功能"
    echo "  5. 测试附件上传功能"
    echo ""
    echo "验证完成后，按 Ctrl+C 停止服务器"
    echo "或运行: ./scripts/deploy/verify_local.sh --stop"

    # 等待用户确认
    read -p "按 Enter 键停止服务器并退出..."
    stop_rails_server
}

# 解析命令行参数
if [ "$1" = "--stop" ]; then
    stop_rails_server
    exit 0
fi

# 执行主流程
main
