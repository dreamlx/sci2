#!/usr/bin/env ruby
# 测试批量优化性能的脚本

require_relative 'config/environment'

puts "🚀 批量优化性能测试"
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

# 测试数据规模
test_sizes = [100, 500, 1000, 2000]

puts "\n📊 批量优化性能对比测试"
puts "=" * 60

test_sizes.each do |size|
  puts "\n🧪 测试数据规模: #{size}条记录"
  puts "-" * 40
  
  # 创建测试CSV数据
  test_csv_content = generate_test_csv_data(size)
  
  # 创建临时CSV文件
  require 'tempfile'
  csv_file = Tempfile.new(['batch_test_reimbursements', '.csv'])
  csv_file.write(test_csv_content)
  csv_file.rewind
  
  results = {}
  
  # 测试原始导入服务
  puts "测试原始导入服务..."
  cleanup_test_data
  
  begin
    original_service = ReimbursementImportService.new(csv_file, admin_user)
    start_time = Time.current
    original_result = original_service.import
    original_duration = Time.current - start_time
    
    results[:original] = {
      duration: original_duration.round(3),
      created: original_result[:created],
      updated: original_result[:updated],
      errors: original_result[:errors],
      records_per_second: (size / original_duration).round(2)
    }
    
    puts "  ✅ 完成 - 耗时: #{original_duration.round(3)}秒, 速度: #{results[:original][:records_per_second]} 记录/秒"
  rescue => e
    puts "  ❌ 失败: #{e.message}"
    results[:original] = { error: e.message }
  end
  
  csv_file.rewind
  
  # 测试优化导入服务
  puts "测试批量优化导入服务..."
  cleanup_test_data
  
  begin
    optimized_service = OptimizedReimbursementImportService.new(csv_file, admin_user)
    start_time = Time.current
    optimized_result = optimized_service.import
    optimized_duration = Time.current - start_time
    
    results[:optimized] = {
      duration: optimized_duration.round(3),
      created: optimized_result[:created],
      updated: optimized_result[:updated],
      errors: optimized_result[:errors],
      records_per_second: (size / optimized_duration).round(2),
      performance_stats: optimized_result[:performance_stats]
    }
    
    puts "  ✅ 完成 - 耗时: #{optimized_duration.round(3)}秒, 速度: #{results[:optimized][:records_per_second]} 记录/秒"
  rescue => e
    puts "  ❌ 失败: #{e.message}"
    results[:optimized] = { error: e.message }
  end
  
  # 性能对比分析
  if results[:original][:duration] && results[:optimized][:duration]
    improvement = ((results[:original][:duration] - results[:optimized][:duration]) / results[:original][:duration] * 100).round(2)
    speed_improvement = (results[:optimized][:records_per_second] / results[:original][:records_per_second]).round(2)
    
    puts "\n📈 性能对比结果:"
    puts "  原始服务:   #{results[:original][:duration]}秒 (#{results[:original][:records_per_second]} 记录/秒)"
    puts "  优化服务:   #{results[:optimized][:duration]}秒 (#{results[:optimized][:records_per_second]} 记录/秒)"
    puts "  时间改善:   #{improvement > 0 ? '+' : ''}#{improvement}%"
    puts "  速度提升:   #{speed_improvement}倍"
    
    if improvement > 50
      puts "  🎉 显著性能提升!"
    elsif improvement > 20
      puts "  ✅ 良好性能提升"
    elsif improvement > 0
      puts "  ➡️  轻微性能提升"
    else
      puts "  ⚠️  性能未提升，需要进一步优化"
    end
  end
  
  # 数据完整性验证
  puts "\n🔍 数据完整性验证:"
  imported_count = Reimbursement.where("invoice_number LIKE 'BATCH_TEST_%'").count
  puts "  导入记录数: #{imported_count}/#{size} (#{imported_count == size ? '✅ 完整' : '❌ 不完整'})"
  
  # 清理测试数据
  cleanup_test_data
  csv_file.close
  csv_file.unlink
  
  puts "\n" + "=" * 40
end

# 辅助方法定义
def generate_test_csv_data(size)
  header = "报销单单号,单据名称,报销单申请人,报销单申请人工号,申请人公司,申请人部门,报销金额（单据币种）,报销单状态\n"
  
  rows = (1..size).map do |i|
    "BATCH_TEST_#{i.to_s.rjust(6, '0')},批量测试报销单#{i},测试用户#{i},EMP#{i.to_s.rjust(4, '0')},测试公司,测试部门,#{rand(1000..10000)},已提交"
  end
  
  header + rows.join("\n")
end

def cleanup_test_data
  # 清理测试数据
  begin
    Reimbursement.where("invoice_number LIKE 'BATCH_TEST_%'").destroy_all
  rescue => e
    Rails.logger.warn "清理测试数据时出现错误: #{e.message}"
    # 如果destroy_all失败，尝试直接删除
    ActiveRecord::Base.connection.execute("DELETE FROM reimbursements WHERE invoice_number LIKE 'BATCH_TEST_%'")
  end
end

puts "\n🎉 批量优化性能测试完成!"