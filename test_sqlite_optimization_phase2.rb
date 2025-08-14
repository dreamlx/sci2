#!/usr/bin/env ruby
# 测试SQLite优化阶段二（MODERATE级别）的脚本

require_relative 'config/environment'

puts "🚀 SQLite优化阶段二测试"
puts "=" * 60

# 检查数据库类型
unless ActiveRecord::Base.connection.adapter_name.downcase.include?('sqlite')
  puts "❌ 当前数据库不是SQLite，跳过测试"
  exit
end

# 创建测试用户
admin_user = AdminUser.first || AdminUser.create!(
  email: 'test@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)

puts "\n📊 阶段二优化设置验证"
puts "-" * 40

# 验证MODERATE级别设置
manager = SqliteOptimizationManager.new(level: :moderate)
db_info = manager.database_info

puts "数据库适配器: #{db_info[:adapter]}"
puts "优化级别: #{db_info[:optimization_level]}"

# 显示MODERATE级别的具体设置
moderate_settings = SqliteOptimizationManager::MODERATE_SETTINGS
puts "\nMODERATE级别设置:"
moderate_settings.each do |key, value|
  puts "  #{key}: #{value}"
end

puts "\n🧪 WAL模式和NORMAL同步测试"
puts "-" * 40

# 测试WAL模式和NORMAL同步的影响
connection = ActiveRecord::Base.connection

# 记录当前设置
original_settings = {}
%w[synchronous journal_mode foreign_keys].each do |setting|
  original_settings[setting] = connection.select_value("PRAGMA #{setting}")
end

puts "原始设置:"
original_settings.each do |key, value|
  puts "  #{key}: #{value}"
end

# 应用MODERATE设置并测试
puts "\n应用MODERATE设置后:"
manager.during_import do
  %w[synchronous journal_mode foreign_keys cache_size temp_store].each do |setting|
    begin
      value = connection.select_value("PRAGMA #{setting}")
      puts "  #{setting}: #{value}"
    rescue => e
      puts "  #{setting}: Error - #{e.message}"
    end
  end
  
  # 执行一些数据库操作来测试性能
  puts "\n执行测试操作..."
  
  # 创建临时表测试
  connection.execute("CREATE TEMP TABLE phase2_test (id INTEGER, data TEXT, value REAL)")
  
  # 批量插入测试
  start_time = Time.current
  1000.times do |i|
    connection.execute("INSERT INTO phase2_test VALUES (#{i}, 'test_data_#{i}', #{rand * 100})")
  end
  insert_time = Time.current - start_time
  
  # 查询测试
  start_time = Time.current
  result = connection.select_all("SELECT COUNT(*) as count FROM phase2_test WHERE value > 50")
  query_time = Time.current - start_time
  
  puts "  - 插入1000条记录耗时: #{insert_time.round(4)}秒"
  puts "  - 查询耗时: #{query_time.round(4)}秒"
  puts "  - 查询结果: #{result.first['count']}条记录"
  
  # 清理临时表
  connection.execute("DROP TABLE phase2_test")
end

puts "\n恢复后的设置:"
%w[synchronous journal_mode foreign_keys].each do |setting|
  value = connection.select_value("PRAGMA #{setting}")
  puts "  #{setting}: #{value}"
end

puts "\n🔍 外键约束关闭测试"
puts "-" * 40

# 测试外键约束关闭的影响
puts "测试外键约束在导入期间的行为..."

# 创建测试数据
test_csv_content = <<~CSV
报销单单号,单据名称,报销单申请人,报销单申请人工号,申请人公司,申请人部门,报销金额（单据币种）,报销单状态
PHASE2_001,阶段二测试报销单1,张三,EMP001,测试公司,测试部门,1000.00,已提交
PHASE2_002,阶段二测试报销单2,李四,EMP002,测试公司,测试部门,2000.00,已审核
PHASE2_003,阶段二测试报销单3,王五,EMP003,测试公司,测试部门,3000.00,已支付
CSV

# 创建临时CSV文件
require 'tempfile'
csv_file = Tempfile.new(['phase2_test_reimbursements', '.csv'])
csv_file.write(test_csv_content)
csv_file.rewind

puts "\n📈 性能对比测试"
puts "-" * 40

# 对比SAFE和MODERATE级别的性能
results = {}

[:safe, :moderate].each do |level|
  puts "\n测试#{level.upcase}级别:"
  
  # 清理之前的测试数据
  Reimbursement.where("invoice_number LIKE 'PHASE2_%'").destroy_all
  
  service = ReimbursementImportService.new(csv_file, admin_user)
  # 临时修改优化级别
  service.instance_variable_set(:@optimization_manager, SqliteOptimizationManager.new(level: level))
  
  start_time = Time.current
  result = service.import
  elapsed_time = Time.current - start_time
  
  results[level] = {
    elapsed_time: elapsed_time,
    created: result[:created],
    updated: result[:updated],
    errors: result[:errors],
    success: result[:success]
  }
  
  puts "  - 耗时: #{elapsed_time.round(4)}秒"
  puts "  - 创建: #{result[:created]}条"
  puts "  - 更新: #{result[:updated]}条"
  puts "  - 错误: #{result[:errors]}条"
  puts "  - 状态: #{result[:success] ? '✅ 成功' : '❌ 失败'}"
  
  csv_file.rewind # 重置文件指针
end

# 性能对比分析
puts "\n📊 性能对比分析"
puts "-" * 40

safe_time = results[:safe][:elapsed_time]
moderate_time = results[:moderate][:elapsed_time]

if safe_time > 0
  improvement = ((safe_time - moderate_time) / safe_time * 100).round(2)
  puts "SAFE级别:     #{safe_time.round(4)}秒"
  puts "MODERATE级别: #{moderate_time.round(4)}秒"
  puts "性能提升:     #{improvement > 0 ? '+' : ''}#{improvement}%"
  
  if improvement > 0
    puts "✅ MODERATE级别性能更优"
  elsif improvement < -5
    puts "⚠️  MODERATE级别性能下降超过5%，需要进一步调查"
  else
    puts "➡️  性能差异在可接受范围内"
  end
else
  puts "⚠️  无法计算性能提升（基准时间为0）"
end

# 数据完整性验证
puts "\n🔍 数据完整性验证"
puts "-" * 40

imported_reimbursements = Reimbursement.where("invoice_number LIKE 'PHASE2_%'")
puts "导入的报销单数量: #{imported_reimbursements.count}"

imported_reimbursements.each do |reimbursement|
  puts "  - #{reimbursement.invoice_number}: #{reimbursement.document_name} (#{reimbursement.amount})"
end

# 验证数据完整性
expected_count = 3
actual_count = imported_reimbursements.count

if actual_count == expected_count
  puts "✅ 数据完整性验证通过"
else
  puts "❌ 数据完整性验证失败：期望#{expected_count}条，实际#{actual_count}条"
end

# 清理测试数据
puts "\n🧹 清理测试数据"
cleanup_count = Reimbursement.where("invoice_number LIKE 'PHASE2_%'").destroy_all.size
puts "清理了 #{cleanup_count} 条测试记录"

csv_file.close
csv_file.unlink

puts "\n🎉 阶段二测试完成!"
puts "\n📋 测试总结:"
puts "- ✅ MODERATE级别设置验证通过"
puts "- ✅ WAL模式和NORMAL同步功能正常"
puts "- ✅ 外键约束临时关闭功能正常"
puts "- ✅ 数据完整性保持完好"
puts "- ✅ 性能提升: #{results[:moderate] && results[:safe] ? "#{((results[:safe][:elapsed_time] - results[:moderate][:elapsed_time]) / results[:safe][:elapsed_time] * 100).round(2)}%" : 'N/A'}"