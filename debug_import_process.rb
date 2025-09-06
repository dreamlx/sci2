#!/usr/bin/env ruby
# 调试导入过程的详细脚本

require_relative './config/environment'

puts "🔍 导入过程详细调试"
puts "=" * 50

# 模拟测试数据
csv_content = <<~CSV
  reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
  EN,00,个人,01,月度交通费,01,"燃油费行程问题","根据SOP规定...","请根据要求...",EN000101
  EN,00,个人,02,市内交通费,02,"出租车行程问题","根据SOP规定...","请根据要求...",EN000102
  MN,01,学术论坛,01,会议讲课费,01,"非讲者库讲者","根据SOP规定...","不符合要求...",MN010101
  MN,01,学术论坛,00,通用,01,"会议权限问题","根据SOP规定...","请提供...",MN010001
CSV

puts "1. 📊 导入前的数据状态"
puts "-" * 30
puts "FeeType 记录数: #{FeeType.count}"
puts "ProblemType 记录数: #{ProblemType.count}"

puts "\n2. 📋 分析CSV数据"
puts "-" * 30
rows = CSV.parse(csv_content, headers: true, encoding: 'UTF-8')
fee_type_combinations = []
problem_type_combinations = []

rows.each_with_index do |row, index|
  fee_key = "#{row['reimbursement_type_code']}-#{row['meeting_type_code']}-#{row['expense_type_code']}"
  problem_key = "#{row['reimbursement_type_code']}-#{row['meeting_type_code']}-#{row['expense_type_code']}-#{row['issue_code']}"
  
  puts "行 #{index + 1}:"
  puts "  FeeType 组合: #{fee_key}"
  puts "  ProblemType 组合: #{problem_key}"
  
  if fee_type_combinations.include?(fee_key)
    puts "  ⚠️  FeeType 组合重复!"
  else
    fee_type_combinations << fee_key
  end
  
  if problem_type_combinations.include?(problem_key)
    puts "  ⚠️  ProblemType 组合重复!"
  else
    problem_type_combinations << problem_key
  end
  puts
end

puts "3. 🔍 检查数据库中是否已存在相关记录"
puts "-" * 30

fee_type_combinations.each do |combination|
  rt_code, mt_code, et_code = combination.split('-')
  existing = FeeType.find_by(reimbursement_type_code: rt_code, meeting_type_code: mt_code, expense_type_code: et_code)
  if existing
    puts "  ⚠️  FeeType 组合 #{combination} 已存在于数据库中"
  else
    puts "  ✅ FeeType 组合 #{combination} 不存在于数据库中"
  end
end

problem_type_combinations.each do |combination|
  rt_code, mt_code, et_code, code = combination.split('-')
  existing = ProblemType.find_by(reimbursement_type_code: rt_code, meeting_type_code: mt_code, expense_type_code: et_code, code: code)
  if existing
    puts "  ⚠️  ProblemType 组合 #{combination} 已存在于数据库中"
  else
    puts "  ✅ ProblemType 组合 #{combination} 不存在于数据库中"
  end
end

puts "\n4. 📥 模拟导入过程"
puts "-" * 30

# 清理测试数据库
FeeType.where(reimbursement_type_code: ['EN', 'MN']).destroy_all
ProblemType.where(reimbursement_type_code: ['EN', 'MN']).destroy_all

puts "清理后的记录数:"
puts "FeeType 记录数: #{FeeType.count}"
puts "ProblemType 记录数: #{ProblemType.count}"

# 模拟导入
import_service = ProblemCodeImportService.new(StringIO.new(csv_content).path)
result = import_service.import

puts "\n导入结果:"
puts "FeeType 记录数: #{FeeType.count}"
puts "ProblemType 记录数: #{ProblemType.count}"
puts "导入结果详情: #{result}"

puts "\n导入的 FeeType 记录:"
FeeType.all.each do |ft|
  puts "  - #{ft.reimbursement_type_code}-#{ft.meeting_type_code}-#{ft.expense_type_code}: #{ft.name}"
end

puts "\n导入的 ProblemType 记录:"
ProblemType.all.each do |pt|
  puts "  - #{pt.reimbursement_type_code}-#{pt.meeting_type_code}-#{pt.expense_type_code}-#{pt.code}: #{pt.title}"
end

puts "\n" + "=" * 50
puts "🎯 关键发现:"
puts "1. 如果导入后记录数不等于4，说明数据库中存在预置数据"
puts "2. 如果导入后记录数等于4，说明导入逻辑正确"
puts "3. 需要检查测试环境的数据隔离"
puts "=" * 50