#!/usr/bin/env ruby
# 大规模批量导入性能对比测试

require_relative 'config/environment'

def generate_large_test_csv(size)
  header = "报销单单号,单据名称,报销单申请人,报销单申请人工号,申请人公司,申请人部门,报销金额（单据币种）,报销单状态\n"
  
  rows = (1..size).map do |i|
    "LARGE_#{i.to_s.rjust(6, '0')},大规模测试报销单#{i},测试用户#{i % 100},EMP#{(i % 1000).to_s.rjust(4, '0')},测试公司#{i % 10},测试部门#{i % 20},#{rand(1000..10000)},已提交"
  end
  
  header + rows.join("\n")
end

def cleanup_large_test_data
  begin
    Reimbursement.where("invoice_number LIKE 'LARGE_%'").delete_all
  rescue => e
    Rails.logger.warn "清理测试数据时出现错误: #{e.message}"
    ActiveRecord::Base.connection.execute("DELETE FROM reimbursements WHERE invoice_number LIKE 'LARGE_%'")
  end
end

puts "🚀 大规模批量导入性能对比测试"
puts "=" * 60

# 创建测试用户
admin_user = AdminUser.first || AdminUser.create!(
  email: 'test@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)

# 测试不同规模的数据
test_sizes = [1000, 2000, 5000]

test_sizes.each do |size|
  puts "\n📊 测试数据规模: #{size}条记录"
  puts "=" * 50
  
  # 生成测试数据
  test_csv_content = generate_large_test_csv(size)
  
  require 'tempfile'
  csv_file = Tempfile.new(['large_test', '.csv'])
  csv_file.write(test_csv_content)
  csv_file.rewind
  
  results = {}
  
  # 测试原始导入服务
  puts "\n🔄 测试原始导入服务..."
  cleanup_large_test_data
  
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
      records_per_second: (size / original_duration).round(2),
      success: original_result[:success]
    }
    
    puts "  ✅ 完成"
    puts "  - 耗时: #{original_duration.round(3)}秒"
    puts "  - 创建: #{original_result[:created]}条"
    puts "  - 速度: #{results[:original][:records_per_second]} 记录/秒"
    
    # 验证数据
    actual_count = Reimbursement.where("invoice_number LIKE 'LARGE_%'").count
    puts "  - 实际导入: #{actual_count}条"
    
  rescue => e
    puts "  ❌ 失败: #{e.message}"
    results[:original] = { error: e.message }
  end
  
  csv_file.rewind
  
  # 测试简化版批量导入服务
  puts "\n⚡ 测试简化版批量导入服务..."
  cleanup_large_test_data
  
  begin
    batch_service = SimpleBatchReimbursementImportService.new(csv_file, admin_user)
    start_time = Time.current
    batch_result = batch_service.import
    batch_duration = Time.current - start_time
    
    results[:batch] = {
      duration: batch_duration.round(3),
      created: batch_result[:created],
      updated: batch_result[:updated],
      errors: batch_result[:errors],
      records_per_second: (size / batch_duration).round(2),
      success: batch_result[:success]
    }
    
    puts "  ✅ 完成"
    puts "  - 耗时: #{batch_duration.round(3)}秒"
    puts "  - 创建: #{batch_result[:created]}条"
    puts "  - 速度: #{results[:batch][:records_per_second]} 记录/秒"
    
    # 验证数据
    actual_count = Reimbursement.where("invoice_number LIKE 'LARGE_%'").count
    puts "  - 实际导入: #{actual_count}条"
    
  rescue => e
    puts "  ❌ 失败: #{e.message}"
    puts "  错误详情: #{e.backtrace.first(3)}"
    results[:batch] = { error: e.message }
  end
  
  # 性能对比分析
  if results[:original][:duration] && results[:batch][:duration]
    puts "\n📈 性能对比分析 (#{size}条记录)"
    puts "-" * 40
    
    original_time = results[:original][:duration]
    batch_time = results[:batch][:duration]
    
    time_improvement = ((original_time - batch_time) / original_time * 100).round(2)
    speed_improvement = (results[:batch][:records_per_second] / results[:original][:records_per_second]).round(2)
    
    puts "原始服务:     #{original_time}秒 (#{results[:original][:records_per_second]} 记录/秒)"
    puts "批量服务:     #{batch_time}秒 (#{results[:batch][:records_per_second]} 记录/秒)"
    puts "时间改善:     #{time_improvement > 0 ? '+' : ''}#{time_improvement}%"
    puts "速度提升:     #{speed_improvement}倍"
    
    if speed_improvement > 10
      puts "🎉 显著性能提升!"
    elsif speed_improvement > 3
      puts "✅ 良好性能提升"
    elsif speed_improvement > 1
      puts "➡️  轻微性能提升"
    else
      puts "⚠️  性能未提升"
    end
    
    # 预测大规模数据处理时间
    puts "\n🔮 大规模数据处理时间预测:"
    [10000, 20000, 50000].each do |scale|
      original_predicted = (scale / results[:original][:records_per_second]).round(1)
      batch_predicted = (scale / results[:batch][:records_per_second]).round(1)
      puts "  #{scale}条记录: 原始#{original_predicted}秒 → 批量#{batch_predicted}秒"
    end
  end
  
  # 清理测试数据
  cleanup_large_test_data
  csv_file.close
  csv_file.unlink
  
  puts "\n" + "=" * 50
end

puts "\n🎉 大规模批量导入性能测试完成!"