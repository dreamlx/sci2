#!/bin/bash
set -e

# 从旧服务器 (192.168.9.209) dump 数据库到本地
# 此脚本用于从旧生产服务器导出 PostgreSQL 数据库并导入到本地开发环境

# 配置
REMOTE_USER="test"
REMOTE_HOST="192.168.9.209"
REMOTE_DB_NAME="sci2_production"
REMOTE_DB_USER="sci2"
REMOTE_DB_PASSWORD="password_123"
REMOTE_DB_HOST="127.0.0.1"
REMOTE_DB_PORT="5432"

LOCAL_DB_NAME="sci2_development"
LOCAL_DB_USER="sci2_test"
LOCAL_DB_PASSWORD="test_password_123"
LOCAL_DB_HOST="localhost"
LOCAL_DB_PORT="55000"

BACKUP_DIR="./db_backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="sci2_production_${TIMESTAMP}.dump"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# 检查依赖
check_dependencies() {
    print_info "检查依赖..."

    if ! command -v ssh &> /dev/null; then
        print_error "ssh 命令未找到"
        exit 1
    fi

    if ! command -v pg_dump &> /dev/null; then
        print_error "pg_dump 命令未找到，请安装 PostgreSQL 客户端工具"
        exit 1
    fi

    if ! command -v psql &> /dev/null; then
        print_error "psql 命令未找到，请安装 PostgreSQL 客户端工具"
        exit 1
    fi

    print_info "依赖检查完成"
}

# 测试 SSH 连接
test_ssh_connection() {
    print_info "测试 SSH 连接到 ${REMOTE_USER}@${REMOTE_HOST}..."

    if ssh -o ConnectTimeout=10 -o BatchMode=yes ${REMOTE_USER}@${REMOTE_HOST} "echo 'SSH 连接成功'" &> /dev/null; then
        print_info "SSH 连接成功"
    else
        print_error "SSH 连接失败，请检查:"
        echo "  1. SSH 密钥是否配置正确"
        echo "  2. 服务器地址是否正确: ${REMOTE_HOST}"
        echo "  3. 用户名是否正确: ${REMOTE_USER}"
        exit 1
    fi
}

# 创建备份目录
create_backup_dir() {
    print_info "创建备份目录: ${BACKUP_DIR}"
    mkdir -p "${BACKUP_DIR}"
}

# 备份本地数据库
backup_local_database() {
    print_info "备份本地数据库..."

    if docker compose ps postgres_test &> /dev/null; then
        # 使用 Docker 容器备份
        docker compose exec -T postgres_test pg_dump -U ${LOCAL_DB_USER} ${LOCAL_DB_NAME} > "${BACKUP_DIR}/local_backup_${TIMESTAMP}.sql" 2>/dev/null || true
        print_info "本地数据库备份完成: ${BACKUP_DIR}/local_backup_${TIMESTAMP}.sql"
    else
        print_warning "Docker 容器未运行，跳过本地数据库备份"
    fi
}

# 在远程服务器上 dump 数据库
dump_remote_database() {
    print_info "在远程服务器上 dump 数据库..."

    # 在远程服务器上执行 pg_dump
    ssh ${REMOTE_USER}@${REMOTE_HOST} << EOF
        set -e
        echo "开始 dump 数据库 ${REMOTE_DB_NAME}..."

        # 创建临时目录
        mkdir -p /tmp/sci2_backup

        # 执行 pg_dump
        PGPASSWORD="${REMOTE_DB_PASSWORD}" pg_dump \
            -h ${REMOTE_DB_HOST} \
            -p ${REMOTE_DB_PORT} \
            -U ${REMOTE_DB_USER} \
            -F c \
            -f /tmp/sci2_backup/${DUMP_FILE} \
            ${REMOTE_DB_NAME}

        echo "数据库 dump 完成: /tmp/sci2_backup/${DUMP_FILE}"

        # 显示文件大小
        ls -lh /tmp/sci2_backup/${DUMP_FILE}
EOF

    if [ $? -eq 0 ]; then
        print_info "远程数据库 dump 成功"
    else
        print_error "远程数据库 dump 失败"
        exit 1
    fi
}

# 下载 dump 文件到本地
download_dump_file() {
    print_info "下载 dump 文件到本地..."

    scp ${REMOTE_USER}@${REMOTE_HOST}:/tmp/sci2_backup/${DUMP_FILE} ${BACKUP_DIR}/

    if [ $? -eq 0 ]; then
        print_info "dump 文件下载完成: ${BACKUP_DIR}/${DUMP_FILE}"
    else
        print_error "dump 文件下载失败"
        exit 1
    fi
}

# 清理远程服务器上的临时文件
cleanup_remote_files() {
    print_info "清理远程服务器上的临时文件..."

    ssh ${REMOTE_USER}@${REMOTE_HOST} << EOF
        rm -f /tmp/sci2_backup/${DUMP_FILE}
        echo "远程临时文件已清理"
EOF
}

# 恢复到本地数据库
restore_to_local() {
    print_info "恢复数据库到本地..."

    # 检查 Docker 容器是否运行
    if ! docker compose ps postgres_test &> /dev/null; then
        print_error "Docker 容器未运行，请先启动: docker compose up -d"
        exit 1
    fi

    # 删除并重建本地数据库
    print_info "删除并重建本地数据库..."
    docker compose exec -T postgres_test psql -U ${LOCAL_DB_USER} postgres << EOF
        DROP DATABASE IF EXISTS ${LOCAL_DB_NAME};
        CREATE DATABASE ${LOCAL_DB_NAME} OWNER ${LOCAL_DB_USER};
EOF

    # 恢复数据库
    print_info "恢复数据库..."
    docker compose exec -T postgres_test pg_restore \
        -U ${LOCAL_DB_USER} \
        -d ${LOCAL_DB_NAME} \
        --no-owner \
        --no-acl \
        < ${BACKUP_DIR}/${DUMP_FILE}

    if [ $? -eq 0 ]; then
        print_info "数据库恢复成功"
    else
        print_error "数据库恢复失败"
        exit 1
    fi
}

# 运行数据库迁移
run_migrations() {
    print_info "运行数据库迁移..."

    RBENV_VERSION=3.4.2 bundle exec rails db:migrate

    if [ $? -eq 0 ]; then
        print_info "数据库迁移完成"
    else
        print_warning "数据库迁移失败，请检查"
    fi
}

# 显示恢复后的数据库信息
show_database_info() {
    print_info "数据库信息:"

    docker compose exec -T postgres_test psql -U ${LOCAL_DB_USER} ${LOCAL_DB_NAME} << EOF
        -- 显示表数量
        SELECT 'Tables' as type, COUNT(*) as count FROM information_schema.tables WHERE table_schema = 'public';

        -- 显示报销单数量
        SELECT 'Reimbursements' as type, COUNT(*) as count FROM reimbursements;

        -- 显示工单数量
        SELECT 'Work Orders' as type, COUNT(*) as count FROM work_orders;

        -- 显示用户数量
        SELECT 'Admin Users' as type, COUNT(*) as count FROM admin_users;
EOF
}

# 主流程
main() {
    echo "=========================================="
    echo "  从旧服务器 dump 数据库到本地"
    echo "=========================================="
    echo ""
    echo "远程服务器: ${REMOTE_USER}@${REMOTE_HOST}"
    echo "远程数据库: ${REMOTE_DB_NAME}"
    echo "本地数据库: ${LOCAL_DB_NAME}"
    echo ""

    # 检查依赖
    check_dependencies

    # 测试 SSH 连接
    test_ssh_connection

    # 创建备份目录
    create_backup_dir

    # 备份本地数据库
    backup_local_database

    # 在远程服务器上 dump 数据库
    dump_remote_database

    # 下载 dump 文件到本地
    download_dump_file

    # 清理远程服务器上的临时文件
    cleanup_remote_files

    # 恢复到本地数据库
    restore_to_local

    # 运行数据库迁移
    run_migrations

    # 显示恢复后的数据库信息
    show_database_info

    echo ""
    print_info "=========================================="
    print_info "  数据库 dump 和恢复完成！"
    print_info "=========================================="
    echo ""
    echo "备份文件位置: ${BACKUP_DIR}/${DUMP_FILE}"
    echo "本地数据库: ${LOCAL_DB_NAME}"
    echo ""
    echo "现在可以启动 Rails 服务器进行测试:"
    echo "  RBENV_VERSION=3.4.2 rails server"
}

# 执行主流程
main
