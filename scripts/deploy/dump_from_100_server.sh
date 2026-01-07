#!/bin/bash
set -e

# 从新生产服务器 (100.98.75.43) 下载 SQLite 数据库并迁移到本地 PostgreSQL
# 此脚本用于从新生产服务器下载 SQLite 数据库并迁移到本地开发环境

# 配置
REMOTE_USER="test"
REMOTE_HOST="100.98.75.43"
REMOTE_DB_PATH="/opt/sci2/shared/db/sci2_production.sqlite3"

LOCAL_DB_NAME="sci2_development"
LOCAL_DB_USER="sci2_test"
LOCAL_DB_PASSWORD="test_password_123"
LOCAL_DB_HOST="localhost"
LOCAL_DB_PORT="55000"

BACKUP_DIR="./db_backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SQLITE_BACKUP_FILE="sci2_production_sqlite_${TIMESTAMP}.sqlite3"

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

# 检查依赖
check_dependencies() {
    print_step "检查依赖..."

    if ! command -v ssh &> /dev/null; then
        print_error "ssh 命令未找到"
        exit 1
    fi

    if ! command -v sqlite3 &> /dev/null; then
        print_error "sqlite3 命令未找到，请安装 SQLite"
        exit 1
    fi

    if ! command -v docker &> /dev/null; then
        print_error "docker 命令未找到，请安装 Docker"
        exit 1
    fi

    print_info "依赖检查完成"
}

# 测试 SSH 连接
test_ssh_connection() {
    print_step "测试 SSH 连接到 ${REMOTE_USER}@${REMOTE_HOST}..."

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
    print_step "创建备份目录: ${BACKUP_DIR}"
    mkdir -p "${BACKUP_DIR}"
}

# 检查远程 SQLite 数据库是否存在
check_remote_database() {
    print_step "检查远程 SQLite 数据库..."

    ssh ${REMOTE_USER}@${REMOTE_HOST} << EOF
        if [ -f "${REMOTE_DB_PATH}" ]; then
            echo "远程数据库文件存在: ${REMOTE_DB_PATH}"
            ls -lh ${REMOTE_DB_PATH}
        else
            echo "错误: 远程数据库文件不存在: ${REMOTE_DB_PATH}"
            exit 1
        fi
EOF

    if [ $? -eq 0 ]; then
        print_info "远程数据库检查通过"
    else
        print_error "远程数据库检查失败"
        exit 1
    fi
}

# 下载 SQLite 数据库
download_sqlite_database() {
    print_step "下载 SQLite 数据库..."

    scp ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DB_PATH} ${BACKUP_DIR}/${SQLITE_BACKUP_FILE}

    if [ $? -eq 0 ]; then
        print_info "SQLite 数据库下载完成: ${BACKUP_DIR}/${SQLITE_BACKUP_FILE}"
    else
        print_error "SQLite 数据库下载失败"
        exit 1
    fi
}

# 显示 SQLite 数据库信息
show_sqlite_info() {
    print_step "SQLite 数据库信息:"

    sqlite3 ${BACKUP_DIR}/${SQLITE_BACKUP_FILE} << EOF
        -- 显示表列表
        SELECT 'Tables' as type, name as info FROM sqlite_master WHERE type='table' ORDER BY name;

        -- 显示报销单数量
        SELECT 'Reimbursements' as type, COUNT(*) as count FROM reimbursements;

        -- 显示工单数量
        SELECT 'Work Orders' as type, COUNT(*) as count FROM work_orders;

        -- 显示用户数量
        SELECT 'Admin Users' as type, COUNT(*) as count FROM admin_users;
EOF
}

# 备份本地 PostgreSQL 数据库
backup_local_database() {
    print_step "备份本地 PostgreSQL 数据库..."

    if docker compose ps postgres_test &> /dev/null; then
        # 使用 Docker 容器备份
        docker compose exec -T postgres_test pg_dump -U ${LOCAL_DB_USER} ${LOCAL_DB_NAME} > ${BACKUP_DIR}/postgres_backup_${TIMESTAMP}.sql 2>/dev/null || true
        print_info "本地 PostgreSQL 数据库备份完成: ${BACKUP_DIR}/postgres_backup_${TIMESTAMP}.sql"
    else
        print_warning "Docker 容器未运行，跳过本地数据库备份"
    fi
}

# 重建本地 PostgreSQL 数据库
rebuild_local_database() {
    print_step "重建本地 PostgreSQL 数据库..."

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

    print_info "本地数据库重建完成"
}

# 运行数据库迁移
run_migrations() {
    print_step "运行数据库迁移..."

    RBENV_VERSION=3.4.2 DATABASE_PORT=${LOCAL_DB_PORT} DATABASE_USERNAME=${LOCAL_DB_USER} DATABASE_PASSWORD=${LOCAL_DB_PASSWORD} bundle exec rails db:migrate

    if [ $? -eq 0 ]; then
        print_info "数据库迁移完成"
    else
        print_warning "数据库迁移失败，请检查"
    fi
}

# 使用 Rails 任务迁移 SQLite 数据到 PostgreSQL
migrate_sqlite_to_postgres() {
    print_step "迁移 SQLite 数据到 PostgreSQL..."

    # 创建临时配置文件
    cat > /tmp/sqlite_to_postgres_config.rb << 'EOF'
# SQLite 数据库配置
sqlite_db_path = ENV['SQLITE_DB_PATH']

# 连接到 SQLite 数据库
require 'sqlite3'
sqlite_db = SQLite3::Database.new(sqlite_db_path)
sqlite_db.results_as_hash = false  # 使用数组格式而不是哈希

# 获取所有表
tables = sqlite_db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name").flatten

puts "找到 #{tables.size} 个表: #{tables.join(', ')}"

# 导出每个表的数据
tables.each do |table|
  puts "处理表: #{table}"

  # 获取表结构
  columns = sqlite_db.execute("PRAGMA table_info(#{table})")
  column_names = columns.map { |col| col[1] }  # 列名在索引1

  # 获取数据
  rows = sqlite_db.execute("SELECT * FROM #{table}")

  # 输出 CSV 格式
  puts "TABLE:#{table}"
  puts "COLUMNS:#{column_names.join(',')}"
  rows.each do |row|
    # 处理 NULL 值和特殊字符
    processed_row = row.map do |value|
      if value.nil?
        '\N'
      else
        value.to_s.gsub('\\', '\\\\').gsub("\n", '\\n').gsub("\t", '\\t').gsub("\r", '\\r')
      end
    end
    puts "ROW:#{processed_row.join("\t")}"
  end
end

sqlite_db.close
EOF

    # 执行迁移
    RBENV_VERSION=3.4.2 \
    DATABASE_PORT=${LOCAL_DB_PORT} \
    DATABASE_USERNAME=${LOCAL_DB_USER} \
    DATABASE_PASSWORD=${LOCAL_DB_PASSWORD} \
    SQLITE_DB_PATH=${BACKUP_DIR}/${SQLITE_BACKUP_FILE} \
    bundle exec rails runner /tmp/sqlite_to_postgres_config.rb > ${BACKUP_DIR}/sqlite_export_${TIMESTAMP}.txt

    if [ $? -eq 0 ]; then
        print_info "SQLite 数据导出完成: ${BACKUP_DIR}/sqlite_export_${TIMESTAMP}.txt"
    else
        print_error "SQLite 数据导出失败"
        exit 1
    fi

    # 导入数据到 PostgreSQL
    print_info "导入数据到 PostgreSQL..."

    # 创建导入脚本
    cat > /tmp/import_to_postgres.rb << 'EOF'
require 'csv'

# 连接到 PostgreSQL
require 'pg'
conn = PG.connect(
  host: ENV['DATABASE_HOST'] || 'localhost',
  port: ENV['DATABASE_PORT'] || '55000',
  dbname: ENV['DATABASE_NAME'] || 'sci2_development',
  user: ENV['DATABASE_USERNAME'] || 'sci2_test',
  password: ENV['DATABASE_PASSWORD'] || 'test_password_123'
)

export_file = ENV['EXPORT_FILE']

current_table = nil
columns = []

File.foreach(export_file) do |line|
  line = line.strip
  next if line.empty?

  if line.start_with?('TABLE:')
    current_table = line.sub('TABLE:', '')
    puts "处理表: #{current_table}"
  elsif line.start_with?('COLUMNS:')
    columns = line.sub('COLUMNS:', '').split(',')
  elsif line.start_with?('ROW:')
    values = line.sub('ROW:', '').split("\t").map do |v|
      if v == '\N'
        'NULL'
      else
        # 转义特殊字符
        escaped = v.gsub('\\', '\\\\').gsub("'", "''")
        "'#{escaped}'"
      end
    end

    # 插入数据
    column_list = columns.map { |c| "\"#{c}\"" }.join(', ')
    values_list = values.join(', ')

    begin
      conn.exec("INSERT INTO #{current_table} (#{column_list}) VALUES (#{values_list})")
    rescue PG::Error => e
      puts "警告: 插入失败 - #{e.message}"
    end
  end
end

conn.close
puts "数据导入完成"
EOF

    RBENV_VERSION=3.4.2 \
    DATABASE_PORT=${LOCAL_DB_PORT} \
    DATABASE_USERNAME=${LOCAL_DB_USER} \
    DATABASE_PASSWORD=${LOCAL_DB_PASSWORD} \
    EXPORT_FILE=${BACKUP_DIR}/sqlite_export_${TIMESTAMP}.txt \
    bundle exec rails runner /tmp/import_to_postgres.rb

    if [ $? -eq 0 ]; then
        print_info "数据导入完成"
    else
        print_error "数据导入失败"
        exit 1
    fi
}

# 验证数据完整性
verify_data() {
    print_step "验证数据完整性..."

    docker compose exec -T postgres_test psql -U ${LOCAL_DB_USER} ${LOCAL_DB_NAME} << EOF
        -- 显示表列表
        SELECT 'Tables' as type, COUNT(*) as count FROM information_schema.tables WHERE table_schema = 'public';

        -- 显示报销单数量
        SELECT 'Reimbursements' as type, COUNT(*) as count FROM reimbursements;

        -- 显示工单数量
        SELECT 'Work Orders' as type, COUNT(*) as count FROM work_orders;

        -- 显示用户数量
        SELECT 'Admin Users' as type, COUNT(*) as count FROM admin_users;
EOF

    print_info "数据验证完成"
}

# 主函数
main() {
    echo "=========================================="
    echo "从 100.98.75.43 下载 SQLite 数据库"
    echo "=========================================="
    echo ""

    check_dependencies
    test_ssh_connection
    create_backup_dir
    check_remote_database
    download_sqlite_database
    show_sqlite_info
    backup_local_database

    echo ""
    print_warning "即将重建本地数据库，所有现有数据将被删除！"
    read -p "是否继续？(yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        print_info "操作已取消"
        exit 0
    fi

    rebuild_local_database
    run_migrations
    migrate_sqlite_to_postgres
    verify_data

    echo ""
    echo "=========================================="
    print_info "数据迁移完成！"
    echo "=========================================="
    echo ""
    echo "备份文件位置: ${BACKUP_DIR}"
    echo "  - SQLite 数据库: ${SQLITE_BACKUP_FILE}"
    echo "  - PostgreSQL 备份: postgres_backup_${TIMESTAMP}.sql"
    echo "  - SQLite 导出文件: sqlite_export_${TIMESTAMP}.txt"
    echo ""
    echo "现在可以启动 Rails 服务器进行测试:"
    echo "  RBENV_VERSION=3.4.2 rails server"
}

# 执行主函数
main
