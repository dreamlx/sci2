#!/bin/bash
set -e

# 从旧服务器 (192.168.9.209) 下载 SQLite 数据库并迁移到 PostgreSQL
# 此脚本用于从旧生产服务器下载 SQLite 数据库并迁移到本地 PostgreSQL

# 配置
REMOTE_USER="test"
REMOTE_HOST="192.168.9.209"
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
sqlite_db.results_as_hash = true

# 获取所有表
tables = sqlite_db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name").map { |row| row['name'] }

puts "发现 #{tables.size} 个表:"
tables.each { |table| puts "  - #{table}" }

# 导出数据到 CSV
require 'csv'
require 'fileutils'

export_dir = File.join(Dir.pwd, 'db_backups', 'sqlite_export')
FileUtils.mkdir_p(export_dir)

tables.each do |table|
  puts "导出表: #{table}"
  
  # 获取表结构
  columns = sqlite_db.execute("PRAGMA table_info(#{table})")
  column_names = columns.map { |col| col['name'] }
  
  # 导出数据
  data = sqlite_db.execute("SELECT * FROM #{table}")
  
  # 写入 CSV
  csv_file = File.join(export_dir, "#{table}.csv")
  CSV.open(csv_file, 'w') do |csv|
    csv << column_names
    data.each do |row|
      csv << column_names.map { |col| row[col] }
    end
  end
  
  puts "  导出 #{data.size} 条记录到 #{csv_file}"
end

sqlite_db.close
puts "数据导出完成"
EOF

    # 执行导出
    print_info "导出 SQLite 数据到 CSV..."
    SQLITE_DB_PATH="${BACKUP_DIR}/${SQLITE_BACKUP_FILE}" RBENV_VERSION=3.4.2 bundle exec ruby /tmp/sqlite_to_postgres_config.rb

    if [ $? -eq 0 ]; then
        print_info "SQLite 数据导出完成"
    else
        print_error "SQLite 数据导出失败"
        exit 1
    fi

    # 使用 Rails 导入任务
    print_info "导入 CSV 数据到 PostgreSQL..."
    RBENV_VERSION=3.4.2 DATABASE_PORT=${LOCAL_DB_PORT} DATABASE_USERNAME=${LOCAL_DB_USER} DATABASE_PASSWORD=${LOCAL_DB_PASSWORD} bundle exec rails runner "
      require 'csv'
      require 'fileutils'
      
      export_dir = File.join(Dir.pwd, 'db_backups', 'sqlite_export')
      
      # 获取所有 CSV 文件
      csv_files = Dir.glob(File.join(export_dir, '*.csv')).sort
      
      puts \"发现 #{csv_files.size} 个 CSV 文件\"
      
      csv_files.each do |csv_file|
        table_name = File.basename(csv_file, '.csv')
        puts \"导入表: #{table_name}\"
        
        # 读取 CSV
        csv_data = CSV.read(csv_file)
        headers = csv_data.shift
        rows = csv_data
        
        # 检查表是否存在
        if ActiveRecord::Base.connection.table_exists?(table_name)
          # 清空表
          ActiveRecord::Base.connection.execute(\"TRUNCATE TABLE #{table_name} CASCADE\")
          
          # 导入数据
          rows.each_slice(1000) do |batch|
            columns = headers.join(', ')
            placeholders = headers.map { '?' }.join(', ')
            
            batch.each do |row|
              # 处理 NULL 值
              values = row.map do |v|
                v.nil? || v.to_s.strip.empty? ? 'NULL' : \"'\#{ActiveRecord::Base.connection.quote_string(v.to_s)}'\"
            end.join(', ')
            
              sql = \"INSERT INTO #{table_name} (#{columns}) VALUES (#{values})\"
              ActiveRecord::Base.connection.execute(sql)
            end
          end
          
          puts \"  导入 #{rows.size} 条记录\"
        else
          puts \"  警告: 表 #{table_name} 不存在，跳过\"
        end
      end
      
      puts \"数据导入完成\"
    "

    if [ $? -eq 0 ]; then
        print_info "数据导入完成"
    else
        print_error "数据导入失败"
        exit 1
    fi
}

# 显示迁移后的数据库信息
show_postgres_info() {
    print_step "PostgreSQL 数据库信息:"

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

# 验证数据完整性
verify_data() {
    print_step "验证数据完整性..."

    # 检查关键表是否有数据
    docker compose exec -T postgres_test psql -U ${LOCAL_DB_USER} ${LOCAL_DB_NAME} -t << EOF
        SELECT 
            CASE 
                WHEN (SELECT COUNT(*) FROM reimbursements) > 0 THEN 'OK'
                ELSE 'FAIL'
            END as reimbursements_check,
            CASE 
                WHEN (SELECT COUNT(*) FROM work_orders) > 0 THEN 'OK'
                ELSE 'FAIL'
            END as work_orders_check,
            CASE 
                WHEN (SELECT COUNT(*) FROM admin_users) > 0 THEN 'OK'
                ELSE 'FAIL'
            END as admin_users_check;
EOF

    print_info "数据完整性验证完成"
}

# 主流程
main() {
    echo "=========================================="
    echo "  SQLite 到 PostgreSQL 数据迁移"
    echo "=========================================="
    echo ""
    echo "远程服务器: ${REMOTE_USER}@${REMOTE_HOST}"
    echo "远程数据库: ${REMOTE_DB_PATH}"
    echo "本地数据库: ${LOCAL_DB_NAME} (PostgreSQL)"
    echo ""

    # 检查依赖
    check_dependencies

    # 测试 SSH 连接
    test_ssh_connection

    # 创建备份目录
    create_backup_dir

    # 检查远程数据库
    check_remote_database

    # 下载 SQLite 数据库
    download_sqlite_database

    # 显示 SQLite 数据库信息
    show_sqlite_info

    # 备份本地数据库
    backup_local_database

    # 重建本地数据库
    rebuild_local_database

    # 运行数据库迁移
    run_migrations

    # 迁移 SQLite 数据到 PostgreSQL
    migrate_sqlite_to_postgres

    # 显示迁移后的数据库信息
    show_postgres_info

    # 验证数据完整性
    verify_data

    echo ""
    print_info "=========================================="
    print_info "  数据迁移完成！"
    print_info "=========================================="
    echo ""
    echo "SQLite 备份文件: ${BACKUP_DIR}/${SQLITE_BACKUP_FILE}"
    echo "PostgreSQL 数据库: ${LOCAL_DB_NAME}"
    echo ""
    echo "现在可以启动 Rails 服务器进行测试:"
    echo "  RBENV_VERSION=3.4.2 DATABASE_PORT=${LOCAL_DB_PORT} DATABASE_USERNAME=${LOCAL_DB_USER} DATABASE_PASSWORD=${LOCAL_DB_PASSWORD} rails server"
    echo ""
    echo "访问地址: http://localhost:3000"
}

# 执行主流程
main
