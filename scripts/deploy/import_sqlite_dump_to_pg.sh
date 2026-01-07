#!/bin/bash
set -e

# 将 SQLite dump 导入到 PostgreSQL
# 这个脚本处理 SQLite 和 PostgreSQL 之间的语法差异
# 包括 Boolean 类型转换 (0/1 -> false/true)
# 并自动重置所有表的 sequence

SQLITE_DUMP="./db_backups/sqlite_full_dump.sql"
PG_DUMP="./db_backups/sqlite_converted_for_pg.sql"

# PostgreSQL 连接参数（可通过环境变量覆盖）
PG_HOST="${DATABASE_HOST:-127.0.0.1}"
PG_PORT="${DATABASE_PORT:-55000}"
PG_USER="${DATABASE_USERNAME:-sci2_test}"
PG_PASSWORD="${DATABASE_PASSWORD:-test_password_123}"
PG_DATABASE="${DATABASE_NAME:-sci2_development}"

# Docker 容器名（可通过环境变量覆盖）
DOCKER_CONTAINER="${DOCKER_CONTAINER:-sci2_test_db}"

# 检测 psql 执行方式：本地或 Docker
if command -v psql &> /dev/null; then
    run_psql() {
        PGPASSWORD="$PG_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" "$PG_DATABASE" "$@"
    }
    run_psql_file() {
        PGPASSWORD="$PG_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" "$PG_DATABASE" < "$1"
    }
    PSQL_MODE="local"
else
    run_psql() {
        docker exec -e PGPASSWORD="$PG_PASSWORD" "$DOCKER_CONTAINER" psql -U "$PG_USER" -d "$PG_DATABASE" "$@"
    }
    run_psql_file() {
        docker exec -i -e PGPASSWORD="$PG_PASSWORD" "$DOCKER_CONTAINER" psql -U "$PG_USER" -d "$PG_DATABASE" < "$1"
    }
    PSQL_MODE="docker"
fi

echo "=== SQLite to PostgreSQL 数据迁移脚本 ==="
echo "目标数据库: $PG_USER@$PG_HOST:$PG_PORT/$PG_DATABASE"
echo "执行方式: $PSQL_MODE"
echo ""

# 检查 dump 文件是否存在
if [ ! -f "$SQLITE_DUMP" ]; then
    echo "错误: 找不到 SQLite dump 文件: $SQLITE_DUMP"
    echo "请先运行 dump_from_old_server.sh 或手动创建 dump 文件"
    exit 1
fi

echo "=== 步骤 1: 转换 SQLite dump 为 PostgreSQL 兼容格式 ==="
echo "  - 移除 AUTOINCREMENT"
echo "  - 转换 Boolean (0->false, 1->true)"

# 提取 INSERT 语句并转换
grep "^INSERT INTO" "$SQLITE_DUMP" | \
    sed 's/AUTOINCREMENT//g' | \
    sed "s/,0,'/,false,'/g" | \
    sed "s/,1,'/,true,'/g" | \
    sed 's/,0,/,false,/g' | \
    sed 's/,1,/,true,/g' | \
    sed 's/,0);$/,false);/' | \
    sed 's/,1);$/,true);/' > "$PG_DUMP"

echo "转换完成: $PG_DUMP"
echo "总记录数: $(wc -l < "$PG_DUMP")"

echo ""
echo "=== 步骤 2: 清空现有数据并导入 ==="

# 清空表（按照外键依赖顺序）
echo "清空现有表数据..."
run_psql -c "TRUNCATE reimbursements CASCADE;" 2>&1 || true
run_psql -c "TRUNCATE fee_details CASCADE;" 2>&1 || true
run_psql -c "TRUNCATE operation_histories CASCADE;" 2>&1 || true
run_psql -c "TRUNCATE sessions CASCADE;" 2>&1 || true

# 导入所有数据
echo "导入数据中..."
run_psql_file "$PG_DUMP" 2>&1 | tail -20

echo ""
echo "=== 步骤 3: 重置所有表的 sequence ==="

RESET_SQL=$(cat <<'EOF'
DO $$
DECLARE
    tbl RECORD;
    max_id BIGINT;
    seq_name TEXT;
BEGIN
    FOR tbl IN
        SELECT tablename FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename NOT IN ('schema_migrations', 'ar_internal_metadata')
    LOOP
        seq_name := tbl.tablename || '_id_seq';
        IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'public' AND sequencename = seq_name) THEN
            EXECUTE format('SELECT COALESCE(MAX(id), 0) FROM %I', tbl.tablename) INTO max_id;
            IF max_id > 0 THEN
                EXECUTE format('SELECT setval(%L, %s, true)', seq_name, max_id);
                RAISE NOTICE 'Reset % to %', seq_name, max_id;
            END IF;
        END IF;
    END LOOP;
END $$;
EOF
)

run_psql -c "$RESET_SQL" 2>&1

echo "Sequence 重置完成"

echo ""
echo "=== 步骤 4: 验证导入结果 ==="
run_psql -c "
SELECT 'reimbursements' as table_name, COUNT(*) as count FROM reimbursements
UNION ALL SELECT 'fee_details', COUNT(*) FROM fee_details
UNION ALL SELECT 'work_orders', COUNT(*) FROM work_orders
UNION ALL SELECT 'admin_users', COUNT(*) FROM admin_users
UNION ALL SELECT 'operation_histories', COUNT(*) FROM operation_histories
UNION ALL SELECT 'reimbursement_assignments', COUNT(*) FROM reimbursement_assignments
UNION ALL SELECT 'work_order_operations', COUNT(*) FROM work_order_operations
UNION ALL SELECT 'work_order_problems', COUNT(*) FROM work_order_problems
UNION ALL SELECT 'work_order_fee_details', COUNT(*) FROM work_order_fee_details
ORDER BY table_name;
"

echo ""
echo "=== 迁移完成 ==="
echo "现在可以正常使用数据库了"