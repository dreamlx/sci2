#!/usr/bin/env ruby

# 详细的测试调试脚本 - 模拟完整的测试流程
require './config/environment'

puts "=== 详细测试调试脚本 ==="
puts

# 1. 检查当前数据库状态
puts "1. 当前数据库状态:"
puts "   ProblemType 数量: #{ProblemType.count}"
puts "   FeeType 数量: #{FeeType.count}"
puts

# 2. 创建测试 CSV 内容
puts "2. 创建测试 CSV 内容:"
csv_content = <<~CSV
  reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
  EN,00,个人,01,月度交通费,01,"燃油费行程问题","根据SOP规定...","请根据要求...",EN000101
  EN,00,个人,02,市内交通费,02,"出租车行程问题","根据SOP规定...","请根据要求...",EN000102
  MN,01,学术论坛,01,会议讲课费,01,"非讲者库讲者","根据SOP规定...","不符合要求...",MN010101
  MN,01,学术论坛,00,通用,01,"会议权限问题","根据SOP规定...","请提供...",MN010001
CSV

puts "   CSV 内容:"
puts csv_content
puts

# 3. 创建临时 CSV 文件
puts "3. 创建临时 CSV 文件:"
require 'tempfile'
file = Tempfile.new(['test_problem_codes', '.csv'])
file.write(csv_content)
file.close
csv_file_path = file.path
puts "   临时文件路径: #{csv_file_path}"
puts "   文件存在: #{File.exist?(csv_file_path)}"
puts

# 4. 检查导入前的数据库状态
puts "4. 导入前的数据库状态:"
puts "   ProblemType 数量: #{ProblemType.count}"
puts "   FeeType 数量: #{FeeType.count}"
puts

# 5. 创建导入服务并执行导入
puts "5. 执行导入:"
service = ProblemCodeImportService.new(csv_file_path)
puts "   导入服务创建完成"
puts "   开始导入..."
import_result = service.import
puts "   导入完成，结果: #{import_result}"
puts

# 6. 检查导入后的数据库状态
puts "6. 导入后的数据库状态:"
puts "   ProblemType 数量: #{ProblemType.count}"
puts "   FeeType 数量: #{FeeType.count}"
puts

# 7. 查看所有 ProblemType 记录
puts "7. 所有 ProblemType 记录:"
ProblemType.all.each do |pt|
  puts "   ID: #{pt.id}"
  puts "   Code: #{pt.code}"
  puts "   Title: #{pt.title}"
  puts "   Reimbursement: #{pt.reimbursement_type_code}"
  puts "   Meeting: #{pt.meeting_type_code}"
  puts "   Expense: #{pt.expense_type_code}"
  puts "   Legacy Problem Code (虚拟字段): #{pt.legacy_problem_code}"
  puts
end

# 8. 尝试测试中的查询
puts "8. 测试查询 - legacy_problem_code: 'EN000101':"
result_by_legacy = ProblemType.find_by(legacy_problem_code: 'EN000101')
puts "   查询结果: #{result_by_legacy.inspect}"
if result_by_legacy
  puts "   找到记录！"
  puts "   reimbursement_type_code: #{result_by_legacy.reimbursement_type_code}"
  puts "   title: #{result_by_legacy.title}"
else
  puts "   未找到记录！"
end
puts

# 9. 尝试用实际字段查询
puts "9. 测试查询 - 实际字段组合:"
result_by_fields = ProblemType.find_by(
  reimbursement_type_code: 'EN',
  meeting_type_code: '00',
  expense_type_code: '01',
  code: '01'
)
puts "   查询结果: #{result_by_fields.inspect}"
if result_by_fields
  puts "   找到记录！"
  puts "   计算出的 legacy_problem_code: #{result_by_fields.legacy_problem_code}"
else
  puts "   未找到记录！"
end
puts

# 10. 检查是否有重复的 legacy_problem_code
puts "10. 检查 legacy_problem_code 唯一性:"
legacy_codes = ProblemType.all.map { |pt| pt.legacy_problem_code }
puts "    所有 legacy_problem_code: #{legacy_codes}"
puts "    重复检查: #{legacy_codes.size == legacy_codes.uniq.size ? '无重复' : '有重复'}"
puts

# 11. 清理临时文件
puts "11. 清理临时文件:"
file.unlink
puts "    临时文件已删除"
puts

puts "=== 详细测试调试完成 ==="