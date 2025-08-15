#!/usr/bin/env ruby
# 简化的批量优化验证测试

require_relative 'config/environment'

puts "🧪 批量优化功能验证测试"
puts "=" * 50

# 创建测试用户
admin_user = AdminUser.first || AdminUser.create!(
  email: 'test@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)

# 清理之前的测试数据
puts "🧹 清理测试数据..."
Reimbursement.where("invoice_number LIKE 'VERIFY_%'").destroy_all

# 创建简单的测试CSV数据
test_csv_content = <<~CSV
报销单单号,单据名称,报销单申请人,报销单申请人工号,申请人公司,申请人部门,报销金额（单据币种）,报销单状态
VERIFY_001,验证测试报销单1,张三,EMP001,测试公司,测试部门,1000.00,已提交
VERIFY_002,验证测试报销单2,李四,EMP002,测试公司,测试部门,2000.00,已审核
VERIFY_003,验证测试报销单3,王五,EMP003,测试公司,测试部门,3000.00,已支付
CSV

require 'tempfile'
csv_file = Tempfile.new(['verify_test', '.csv'])
csv_file.write(test_csv_content)
csv_file.rewind

puts "\n📊 测试BatchImportManager基础功能"
puts "-" * 40

begin
  # 测试BatchImportManager
  manager = BatchImportManager.new(Reimbursement, optimization_level: :moderate)
  
  puts "✅ BatchImportManager创建成功"
  puts "   - 模型类: #{manager.model_class.name}"
  puts "   - 优化级别: #{manager.optimization_level}"
  
  # 测试数据库信息
  db_info = manager.sqlite_manager.database_info
  puts "   - 数据库类型: #{db_info[:adapter]}"
  
rescue => e
  puts "❌ BatchImportManager测试失败: #{e.message}"
  puts e.backtrace.first(3)
end

puts "\n📊 测试原始导入服务"
puts "-" * 40

begin
  original_service = ReimbursementImportService.new(csv_file, admin_user)
  start_time = Time.current
  original_result = original_service.import
  original_duration = Time.current - start_time
  
  puts "✅ 原始导入服务测试完成"
  puts "   - 耗时: #{original_duration.round(3)}秒"
  puts "   - 创建: #{original_result[:created]}条"
  puts "   - 更新: #{original_result[:updated]}条"
  puts "   - 错误: #{original_result[:errors]}条"
  
  # 验证数据
  imported_count = Reimbursement.where("invoice_number LIKE 'VERIFY_%'").count
  puts "   - 实际导入: #{imported_count}条"
  
rescue => e
  puts "❌ 原始导入服务测试失败: #{e.message}"
  puts e.backtrace.first(3)
end

# 清理数据准备下一个测试
Reimbursement.where("invoice_number LIKE 'VERIFY_%'").destroy_all
csv_file.rewind

puts "\n⚡ 测试批量优化导入服务"
puts "-" * 40

begin
  optimized_service = OptimizedReimbursementImportService.new(csv_file, admin_user)
  start_time = Time.current
  optimized_result = optimized_service.import
  optimized_duration = Time.current - start_time
  
  puts "✅ 批量优化导入服务测试完成"
  puts "   - 耗时: #{optimized_duration.round(3)}秒"
  puts "   - 创建: #{optimized_result[:created]}条"
  puts "   - 更新: #{optimized_result[:updated]}条"
  puts "   - 错误: #{optimized_result[:errors]}条"
  puts "   - 成功: #{optimized_result[:success]}"
  
  if optimized_result[:error_details].any?
    puts "   - 错误详情: #{optimized_result[:error_details]}"
  end
  
  # 验证数据
  imported_count = Reimbursement.where("invoice_number LIKE 'VERIFY_%'").count
  puts "   - 实际导入: #{imported_count}条"
  
  # 显示导入的记录
  if imported_count > 0
    puts "   - 导入的记录:"
    Reimbursement.where("invoice_number LIKE 'VERIFY_%'").each do |r|
      puts "     * #{r.invoice_number}: #{r.document_name} (#{r.amount})"
    end
  end
  
rescue => e
  puts "❌ 批量优化导入服务测试失败: #{e.message}"
  puts "错误详情:"
  puts e.backtrace.first(5)
end

# 清理测试数据
puts "\n🧹 最终清理"
Reimbursement.where("invoice_number LIKE 'VERIFY_%'").destroy_all

csv_file.close
csv_file.unlink

puts "\n🎉 验证测试完成!"