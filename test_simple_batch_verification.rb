#!/usr/bin/env ruby
# 测试简化版批量导入服务

require_relative 'config/environment'

puts "🧪 简化版批量导入服务验证"
puts "=" * 50

# 创建测试用户
admin_user = AdminUser.first || AdminUser.create!(
  email: 'test@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)

# 清理测试数据
puts "🧹 清理测试数据..."
Reimbursement.where("invoice_number LIKE 'SIMPLE_%'").destroy_all

# 创建测试CSV数据
test_csv_content = <<~CSV
报销单单号,单据名称,报销单申请人,报销单申请人工号,申请人公司,申请人部门,报销金额（单据币种）,报销单状态
SIMPLE_001,简化测试报销单1,张三,EMP001,测试公司,测试部门,1000.00,已提交
SIMPLE_002,简化测试报销单2,李四,EMP002,测试公司,测试部门,2000.00,已审核
SIMPLE_003,简化测试报销单3,王五,EMP003,测试公司,测试部门,3000.00,已支付
SIMPLE_004,简化测试报销单4,赵六,EMP004,测试公司,测试部门,4000.00,已提交
SIMPLE_005,简化测试报销单5,钱七,EMP005,测试公司,测试部门,5000.00,已审核
CSV

require 'tempfile'
csv_file = Tempfile.new(['simple_batch_test', '.csv'])
csv_file.write(test_csv_content)
csv_file.rewind

puts "\n📊 测试简化版批量导入服务"
puts "-" * 40

begin
  service = SimpleBatchReimbursementImportService.new(csv_file, admin_user)
  
  start_time = Time.current
  result = service.import
  duration = Time.current - start_time
  
  puts "✅ 导入完成"
  puts "   - 耗时: #{duration.round(3)}秒"
  puts "   - 成功: #{result[:success]}"
  puts "   - 创建: #{result[:created]}条"
  puts "   - 更新: #{result[:updated]}条"
  puts "   - 错误: #{result[:errors]}条"
  
  if result[:error_details].any?
    puts "   - 错误详情:"
    result[:error_details].each { |error| puts "     * #{error}" }
  end
  
  # 验证实际导入的数据
  imported_reimbursements = Reimbursement.where("invoice_number LIKE 'SIMPLE_%'")
  puts "\n🔍 数据验证结果:"
  puts "   - 实际导入记录数: #{imported_reimbursements.count}"
  puts "   - 期望记录数: 5"
  puts "   - 数据完整性: #{imported_reimbursements.count == 5 ? '✅ 完整' : '❌ 不完整'}"
  
  if imported_reimbursements.any?
    puts "   - 导入的记录:"
    imported_reimbursements.order(:invoice_number).each do |r|
      puts "     * #{r.invoice_number}: #{r.document_name} (#{r.amount}) - #{r.status}"
    end
  end
  
  # 计算性能
  if duration > 0 && imported_reimbursements.count > 0
    records_per_second = (imported_reimbursements.count / duration).round(2)
    puts "   - 处理速度: #{records_per_second} 记录/秒"
  end
  
rescue => e
  puts "❌ 测试失败: #{e.message}"
  puts "错误详情:"
  puts e.backtrace.first(5)
end

# 测试更新功能
puts "\n📊 测试批量更新功能"
puts "-" * 40

# 修改CSV数据来测试更新
updated_csv_content = <<~CSV
报销单单号,单据名称,报销单申请人,报销单申请人工号,申请人公司,申请人部门,报销金额（单据币种）,报销单状态
SIMPLE_001,更新后的报销单1,张三,EMP001,测试公司,测试部门,1500.00,已审核
SIMPLE_002,更新后的报销单2,李四,EMP002,测试公司,测试部门,2500.00,已支付
SIMPLE_006,新增的报销单6,新用户,EMP006,测试公司,测试部门,6000.00,已提交
CSV

csv_file.rewind
csv_file.truncate(0)
csv_file.write(updated_csv_content)
csv_file.rewind

begin
  service = SimpleBatchReimbursementImportService.new(csv_file, admin_user)
  
  start_time = Time.current
  result = service.import
  duration = Time.current - start_time
  
  puts "✅ 更新测试完成"
  puts "   - 耗时: #{duration.round(3)}秒"
  puts "   - 成功: #{result[:success]}"
  puts "   - 创建: #{result[:created]}条"
  puts "   - 更新: #{result[:updated]}条"
  puts "   - 错误: #{result[:errors]}条"
  
  # 验证更新结果
  all_records = Reimbursement.where("invoice_number LIKE 'SIMPLE_%'").order(:invoice_number)
  puts "\n🔍 更新验证结果:"
  puts "   - 总记录数: #{all_records.count}"
  
  all_records.each do |r|
    puts "     * #{r.invoice_number}: #{r.document_name} (#{r.amount}) - #{r.status}"
  end
  
rescue => e
  puts "❌ 更新测试失败: #{e.message}"
  puts e.backtrace.first(3)
end

# 清理测试数据
puts "\n🧹 清理测试数据"
cleanup_count = Reimbursement.where("invoice_number LIKE 'SIMPLE_%'").destroy_all.size
puts "清理了 #{cleanup_count} 条测试记录"

csv_file.close
csv_file.unlink

puts "\n🎉 简化版批量导入验证完成!"