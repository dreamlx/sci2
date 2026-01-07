#!/bin/bash
set -e

# 将 SQLite dump 导入到 PostgreSQL
# 这个脚本处理 SQLite 和 PostgreSQL 之间的语法差异
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
    # 本地有 psql，直接使用
    run_psql() {
        PGPASSWORD="$PG_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" "$PG_DATABASE" "$@"
    }
    run_psql_file() {
        PGPASSWORD="$PG_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" "$PG_DATABASE" < "$1"
    }
    PSQL_MODE="local"
else
    # 使用 Docker 容器内的 psql
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

# 创建转换后的 SQL 文件
> "$PG_DUMP"

# 逐行处理
while IFS= read -r line; do
    # 跳过 SQLite 特定的命令
    if [[ "$line" == PRAGMA* ]]; then
        continue
    fi

    # 跳过 SQLite 的自增主键定义
    if [[ "$line" == *"AUTOINCREMENT"* ]]; then
        # 将 AUTOINCREMENT 替换为空（PostgreSQL 使用 SERIAL）
        line=$(echo "$line" | sed 's/AUTOINCREMENT//g')
    fi

    # 处理 BEGIN TRANSACTION
    if [[ "$line" == "BEGIN TRANSACTION;" ]]; then
        echo "BEGIN;" >> "$PG_DUMP"
        continue
    fi

    # 处理 COMMIT
    if [[ "$line" == "COMMIT;" ]]; then
        echo "COMMIT;" >> "$PG_DUMP"
        continue
    fi

    # 处理表创建语句中的数据类型差异
    # SQLite 的 boolean 在 PostgreSQL 中保持 boolean
    # SQLite 的 datetime(6) 在 PostgreSQL 中使用 timestamp

    # 处理 CREATE TABLE 语句
    if [[ "$line" == CREATE\ TABLE* ]]; then
        # 移除 IF NOT EXISTS 后的 SQLite 特定语法
        line=$(echo "$line" | sed 's/IF NOT EXISTS //g')
    fi

    # 处理 INSERT INTO 语句
    if [[ "$line" == INSERT\ INTO* ]]; then
        # SQLite 的 INSERT 语法与 PostgreSQL 兼容
        :
    fi

    echo "$line" >> "$PG_DUMP"
done < "$SQLITE_DUMP"

echo "转换完成: $PG_DUMP"

echo ""
echo "=== 步骤 2: 导入数据到 PostgreSQL ==="

# 只导入缺失的数据表（不清除现有数据，只插入）
TABLES=("reimbursement_assignments" "work_order_operations" "work_order_problems" "work_order_fee_details")

for table in "${TABLES[@]}"; do
    echo "处理表: $table"

    # 提取该表的 INSERT 语句
    # 使用 awk 提取从 INSERT INTO table_name 到下一个 INSERT 或 COMMIT 的内容

    awk -v table="$table" '
        $0 == "BEGIN;" { in_transaction = 1; print; next }
        $0 == "COMMIT;" { in_transaction = 0; print; next }
        in_transaction && $0 ~ "INSERT INTO \"" table "\"" {
            in_table = 1
            print
            next
        }
        in_table {
            if ($0 ~ /^INSERT INTO/) {
                print
            } else if ($0 == "COMMIT;") {
                print
                in_table = 0
            } else {
                print
            }
            next
        }
    ' "$PG_DUMP" > "/tmp/${table}_inserts.sql"

    # 导入数据
    if [ -s "/tmp/${table}_inserts.sql" ]; then
        run_psql_file "/tmp/${table}_inserts.sql" 2>&1 || true
        echo "  $table 数据导入完成"
    else
        echo "  警告: 没有找到 $table 的数据"
    fi
done

echo ""
echo "=== 步骤 3: 重置所有表的 sequence ==="

# 创建重置 sequence 的 SQL
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

        -- 检查 sequence 是否存在
        IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'public' AND sequencename = seq_name) THEN
            -- 获取表中的最大 id
            EXECUTE format('SELECT COALESCE(MAX(id), 0) FROM %I', tbl.tablename) INTO max_id;

            IF max_id > 0 THEN
                -- 重置 sequence
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
UNION ALL SELECT 'reimbursement_assignments', COUNT(*) FROM reimbursement_assignments
UNION ALL SELECT 'work_order_operations', COUNT(*) FROM work_order_operations
UNION ALL SELECT 'work_order_problems', COUNT(*) FROM work_order_problems
UNION ALL SELECT 'work_order_fee_details', COUNT(*) FROM work_order_fee_details
UNION ALL SELECT 'operation_histories', COUNT(*) FROM operation_histories
ORDER BY table_name;
"

echo ""
echo "=== 步骤 5: 验证 sequence 状态 ==="
run_psql -c "
SELECT
    sequencename as sequence_name,
    last_value
FROM pg_sequences
WHERE schemaname = 'public'
ORDER BY sequencename;
"

echo ""
echo "=== 迁移完成 ==="
echo "现在可以正常使用开发环境了"
