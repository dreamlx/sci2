#!/usr/bin/env ruby
# frozen_string_literal: true

# 从 SQLite 导入数据到 PostgreSQL
# 这个脚本处理 SQLite 和 PostgreSQL 之间的数据类型差异
# 包括 Boolean 类型转换 (0/1 -> FALSE/TRUE)

require 'sqlite3'
require 'pg'

# SQLite 数据库路径（可通过命令行参数指定）
SQLITE_DB = ARGV[0] || './db_backups/sci2_production.sqlite3'

unless File.exist?(SQLITE_DB)
  puts "错误: 找不到 SQLite 文件: #{SQLITE_DB}"
  puts "用法: ruby import_sqlite_to_pg.rb [sqlite_db_path]"
  exit 1
end

# PostgreSQL 连接参数（可通过环境变量覆盖）
PG_CONFIG = {
  host: ENV['DATABASE_HOST'] || 'localhost',
  port: (ENV['DATABASE_PORT'] || 55_000).to_i,
  dbname: ENV['DATABASE_NAME'] || 'sci2_development',
  user: ENV['DATABASE_USERNAME'] || 'sci2_test',
  password: ENV['DATABASE_PASSWORD'] || 'test_password_123'
}.freeze

# 要导入的表（按依赖顺序）
TABLES = %w[
  admin_users
  reimbursements
  fee_types
  problem_types
  fee_details
  work_orders
  operation_histories
  reimbursement_assignments
  work_order_fee_details
  work_order_operations
  work_order_problems
  work_order_status_changes
  communication_records
  import_performances
  active_admin_comments
  sessions
  active_storage_blobs
  active_storage_attachments
  active_storage_variant_records
].freeze

def escape_value(value, column_name = nil)
  return 'NULL' if value.nil?

  # 清理列名（移除引号）
  clean_column_name = column_name&.gsub('"', '')

  # 检查是否是布尔类型字段
  boolean_fields = %w[is_electronic active is_active vat_verified needs_communication manual_override has_updates]
  if clean_column_name && boolean_fields.include?(clean_column_name)
    case value
    when 0, '0', false, 'false', 'FALSE'
      return 'FALSE'
    when 1, '1', true, 'true', 'TRUE'
      return 'TRUE'
    end
  end

  case value
  when Integer, Float
    value.to_s
  when true, false
    value.to_s
  when String
    # 处理特殊字符
    escaped = value.gsub("'", "''")
    "'#{escaped}'"
  when Date, Time, DateTime
    "'#{value.strftime('%Y-%m-%d %H:%M:%S')}'"
  else
    "'#{value.to_s.gsub("'", "''")}'"
  end
end

def get_columns(conn, table_name)
  result = conn.exec("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '#{table_name}'")
  Hash[result.map { |row| [row['column_name'], row['data_type']] }]
end

def import_table(sqlite_db, conn, table_name)
  puts "导入表: #{table_name}"

  # 先获取列名（PRAGMA 返回数组格式，列名在索引 1）
  column_result = sqlite_db.execute("PRAGMA table_info(#{table_name})")
  column_names = column_result.map { |row| row[1] }
  column_list = column_names.map { |c| "\"#{c}\"" }.join(', ')

  # 获取 SQLite 数据
  rows = sqlite_db.execute("SELECT * FROM #{table_name}").to_a

  return if rows.empty?

  # PostgreSQL: 禁用外键约束检查
  # 注意: session_replication_role = replica 会禁用触发器和外键检查

  # 批量插入
  batch_size = 1000
  batch = []

  rows.each_with_index do |row, idx|
    values = row.each_with_index.map { |v, i| escape_value(v, column_names[i]) }
    sql = "INSERT INTO #{table_name} (#{column_list}) VALUES (#{values.join(', ')})"
    batch << sql

    next unless batch.size >= batch_size

    conn.exec(batch.join(';'))
    batch.clear
    print '.'
  end

  # 插入剩余的数据
  conn.exec(batch.join(';')) unless batch.empty?

  puts " (#{rows.count} 行)"
rescue PG::Error => e
  puts " 错误: #{e.message}"
end

# 主程序
puts '=== 从 SQLite 导入数据到 PostgreSQL ==='
puts "SQLite: #{SQLITE_DB}"
puts "PostgreSQL: #{PG_CONFIG[:user]}@#{PG_CONFIG[:host]}:#{PG_CONFIG[:port]}/#{PG_CONFIG[:dbname]}"
puts ''

conn = PG.connect(PG_CONFIG)
sqlite_db = SQLite3::Database.new(SQLITE_DB)

# 禁用外键约束
conn.exec('SET session_replication_role = replica')

TABLES.each do |table|
  import_table(sqlite_db, conn, table)
end

# 恢复外键约束
conn.exec('SET session_replication_role = DEFAULT')

sqlite_db.close

# 重置所有表的 sequence
puts ''
puts '=== 重置 sequence ==='
reset_sql = <<~SQL
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
SQL
conn.exec(reset_sql)
puts 'Sequence 重置完成'

# 验证结果
puts ''
puts '=== 数据统计 ==='
%w[reimbursements work_orders admin_users fee_details operation_histories reimbursement_assignments].each do |table|
  result = conn.exec("SELECT COUNT(*) as count FROM #{table}")
  puts "#{table}: #{result.first['count']} 行"
end

conn.close
puts ''
puts '=== 导入完成 ==='
