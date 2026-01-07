#!/usr/bin/env ruby
# frozen_string_literal: true

# 从 SQLite 导入数据到 PostgreSQL
# 这个脚本处理 SQLite 和 PostgreSQL 之间的数据类型差异

require 'sqlite3'
require 'pg'

SQLITE_DB = './db_backups/sci2_production_sqlite_20260106_180951.sqlite3'

# PostgreSQL 连接
conn = PG.connect(
  host: 'localhost',
  port: 55_000,
  dbname: 'sci2_development',
  user: 'sci2_test',
  password: 'test_password_123'
)

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

  # 禁用外键检查（如果支持）
  begin
    conn.exec('SET FOREIGN_KEY_CHECKS = 0')
  rescue StandardError
    nil
  end

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

  # 启用外键检查
  begin
    conn.exec('SET FOREIGN_KEY_CHECKS = 1')
  rescue StandardError
    nil
  end

  puts " (#{rows.count} 行)"
rescue PG::Error => e
  puts " 错误: #{e.message}"
end

# 主程序
puts '=== 从 SQLite 导入数据到 PostgreSQL ==='
puts ''

sqlite_db = SQLite3::Database.new(SQLITE_DB)

TABLES.each do |table|
  import_table(sqlite_db, conn, table)
end

sqlite_db.close
conn.close

puts ''
puts '=== 导入完成 ==='

# 验证结果
puts ''
puts '=== 数据统计 ==='
conn = PG.connect(
  host: 'localhost',
  port: 55_000,
  dbname: 'sci2_development',
  user: 'sci2_test',
  password: 'test_password_123'
)

%w[reimbursements work_orders admin_users fee_details reimbursement_assignments work_order_operations].each do |table|
  result = conn.exec("SELECT COUNT(*) as count FROM #{table}")
  puts "#{table}: #{result.first['count']} 行"
end

conn.close
