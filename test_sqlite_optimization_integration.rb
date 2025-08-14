#!/usr/bin/env ruby
# 测试SQLite优化集成的简单脚本

require_relative 'config/environment'

puts "🧪 SQLite优化集成测试"
puts "=" * 50

# 创建测试用户
admin_user = AdminUser.first || AdminUser.create!(
  email: 'test@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)

# 创建测试CSV数据
test_csv_content = <<~CSV
报销单单号,单据名称,报销单申请人,报销单申请人工号,申请人公司,申请人部门,报销金额（单据币种）,报销单状态
INTEGRATION001,集成测试报销单1,张三,EMP001,测试公司,测试部门,1000.00,已提交
INTEGRATION002,集成测试报销单2,李四,EMP002,测试公司,测试部门,2000.00,已审核
INTEGRATION003,集成测试报销单3,王五,EMP003,测试公司,测试部门,3000.00,已支付
CSV

# 创建临时CSV文件
require 'tempfile'
csv_file = Tempfile.new(['test_reimbursements', '.csv'])
csv_file.write(test_csv_content)
csv_file.rewind

puts "\n📊 测试报销单导入服务集成"
puts "-" * 30

begin
  # 测试ReimbursementImportService
  service = ReimbursementImportService.new(csv_file, admin_user)
  
  start_time = Time.current
  result = service.import
  elapsed_time = Time.current - start_time
  
  puts "✅ 导入完成"
  puts "   - 耗时: #{elapsed_time.round(3)}秒"
  puts "   - 创建: #{result[:created]}条"
  puts "   - 更新: #{result[:updated]}条"
  puts "   - 错误: #{result[:errors]}条"
  
  if result[:success]
    puts "   - 状态: ✅ 成功"
  else
    puts "   - 状态: ❌ 失败"
    puts "   - 错误详情: #{result[:error_details]}"
  end
  
rescue => e
  puts "❌ 测试失败: #{e.message}"
  puts e.backtrace.first(5)
ensure
  csv_file.close
  csv_file.unlink
end

# 清理测试数据
puts "\n🧹 清理测试数据"
cleanup_count = Reimbursement.where("invoice_number LIKE 'INTEGRATION%'").destroy_all.size
puts "   - 清理了 #{cleanup_count} 条测试记录"

puts "\n🎉 集成测试完成!"