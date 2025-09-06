#!/usr/bin/env ruby

# Debug script to understand why the test queries are failing
require './config/environment'

puts "=== 测试查询调试脚本 ==="
puts

# 1. 检查是否有任何 ProblemType 记录
puts "1. 检查 ProblemType 记录总数:"
problem_types_count = ProblemType.count
puts "   总数: #{problem_types_count}"
puts

# 2. 检查所有 ProblemType 记录的详细信息
puts "2. 所有 ProblemType 记录:"
ProblemType.all.each do |pt|
  puts "   ID: #{pt.id}, Code: #{pt.code}, Title: #{pt.title}"
  puts "   Reimbursement: #{pt.reimbursement_type_code}, Meeting: #{pt.meeting_type_code}, Expense: #{pt.expense_type_code}"
  puts "   Legacy Problem Code (虚拟字段): #{pt.legacy_problem_code}"
  puts "   Fee Type ID: #{pt.respond_to?(:fee_type_id) ? pt.fee_type_id : 'N/A'}"
  puts
end

# 3. 尝试用虚拟字段查询（应该失败）
puts "3. 尝试用虚拟字段查询:"
begin
  result = ProblemType.find_by(legacy_problem_code: 'EN000101')
  puts "   查询结果: #{result.inspect}"
rescue => e
  puts "   查询失败: #{e.message}"
end
puts

# 4. 用实际字段查询
puts "4. 用实际字段查询:"
result = ProblemType.find_by(
  reimbursement_type_code: 'EN',
  meeting_type_code: '00', 
  expense_type_code: '01',
  code: '01'
)
puts "   查询结果: #{result.inspect}"
if result
  puts "   计算出的 legacy_problem_code: #{result.legacy_problem_code}"
end
puts

# 5. 检查数据库模式
puts "5. 检查 ProblemType 的列名:"
puts ProblemType.column_names
puts

# 6. 模拟测试场景
puts "6. 模拟测试场景 - 创建导入服务:"
csv_file_path = Rails.root.join('spec', 'fixtures', 'problem_codes.csv')
if File.exist?(csv_file_path)
  puts "   CSV 文件存在: #{csv_file_path}"
  
  # 检查导入前的记录数
  puts "   导入前记录数: #{ProblemType.count}"
  
  # 创建导入服务
  service = ProblemCodeImportService.new(csv_file_path)
  
  # 执行导入
  puts "   执行导入..."
  service.import
  
  # 检查导入后的记录数
  puts "   导入后记录数: #{ProblemType.count}"
  
  # 再次尝试查询
  puts "   再次尝试查询:"
  result = ProblemType.find_by(
    reimbursement_type_code: 'EN',
    meeting_type_code: '00', 
    expense_type_code: '01',
    code: '01'
  )
  puts "   查询结果: #{result.inspect}"
  if result
    puts "   计算出的 legacy_problem_code: #{result.legacy_problem_code}"
  end
else
  puts "   CSV 文件不存在: #{csv_file_path}"
end

puts "=== 调试完成 ==="