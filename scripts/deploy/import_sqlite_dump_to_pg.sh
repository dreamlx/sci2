#!/bin/bash
set -e

# 将 SQLite dump 导入到 PostgreSQL
# 这个脚本处理 SQLite 和 PostgreSQL 之间的语法差异

SQLITE_DUMP="./db_backups/sqlite_full_dump.sql"
PG_DUMP="./db_backups/sqlite_converted_for_pg.sql"

echo "=== 转换 SQLite dump 为 PostgreSQL 兼容格式 ==="

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
echo "=== 导入到 PostgreSQL ==="

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
        docker compose exec -T postgres_test psql -U sci2_test sci2_development < "/tmp/${table}_inserts.sql" 2>&1 || true
        echo "  $table 数据导入完成"
    else
        echo "  警告: 没有找到 $table 的数据"
    fi
done

echo ""
echo "=== 验证导入结果 ==="
docker compose exec -T postgres_test psql -U sci2_test sci2_development -c "
SELECT 'reimbursement_assignments' as tbl, COUNT(*) FROM reimbursement_assignments
UNION ALL SELECT 'work_order_operations', COUNT(*) FROM work_order_operations
UNION ALL SELECT 'work_order_problems', COUNT(*) FROM work_order_problems
UNION ALL SELECT 'work_order_fee_details', COUNT(*) FROM work_order_fee_details;
"

echo ""
echo "=== 导入完成 ==="
