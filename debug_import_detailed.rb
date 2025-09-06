#!/usr/bin/env ruby
# 详细调试导入过程的脚本

require_relative './config/environment'

puts "🔍 导入过程详细分析"
puts "=" * 50

# 创建临时CSV文件
csv_content = <<~CSV
  reimbursement_type_code,meeting_type_code,meeting_type_name,expense_type_code,expense_type_name,issue_code,problem_title,sop_description,standard_handling,legacy_problem_code
  EN,00,个人,01,月度交通费,01,"燃油费行程问题","根据SOP规定...","请根据要求...",EN000101
  EN,00,个人,02,市内交通费,02,"出租车行程问题","根据SOP规定...","请根据要求...",EN000102
  MN,01,学术论坛,01,会议讲课费,01,"非讲者库讲者","根据SOP规定...","不符合要求...",MN010101
  MN,01,学术论坛,00,通用,01,"会议权限问题","根据SOP规定...","请提供...",MN010001
CSV

# 创建临时文件
temp_file = Tempfile.new(['test_import', '.csv'])
temp_file.write(csv_content)
temp_file.close

puts "1. 📊 导入前的记录数量"
puts "-" * 30
puts "FeeType 记录数: #{FeeType.count}"
puts "ProblemType 记录数: #{ProblemType.count}"

puts "\n2. 📋 测试数据组合分析"
puts "-" * 30

rows = CSV.parse(csv_content, headers: true, encoding: 'UTF-8')
fee_type_keys = []
problem_type_keys = []

rows.each_with_index do |row, index|
  fee_key = "#{row['reimbursement_type_code']}-#{row['meeting_type_code']}-#{row['expense_type_code']}"
  problem_key = "#{row['reimbursement_type_code']}-#{row['meeting_type_code']}-#{row['expense_type_code']}-#{row['issue_code']}"
  
  puts "行 #{index + 1}:"
  puts "  FeeType: #{fee_key}"
  puts "  ProblemType: #{problem_key}"
  
  # 检查是否已存在
  fee_exists = FeeType.find_by(reimbursement_type_code: row['reimbursement_type_code'], 
                               meeting_type_code: row['meeting_type_code'], 
                               expense_type_code: row['expense_type_code'])
  problem_exists = ProblemType.find_by(reimbursement_type_code: row['reimbursement_type_code'], 
                                      meeting_type_code: row['meeting_type_code'], 
                                      expense_type_code: row['expense_type_code'], 
                                      code: row['issue_code'])
  
  puts "  FeeType 存在: #{fee_exists ? '是' : '否'}"
  puts "  ProblemType 存在: #{problem_exists ? '是' : '否'}"
  puts
end

puts "3. 🔄 模拟导入过程"
puts "-" * 30

# 手动模拟导入过程，记录每一步的结果
imported_fee_types = 0
updated_fee_types = 0
imported_problem_types = 0
updated_problem_types = 0

rows.each_with_index do |row, index|
  puts "\n处理行 #{index + 1}:"
  
  # 处理 FeeType
  fee_type = FeeType.find_or_initialize_by(
    reimbursement_type_code: row['reimbursement_type_code'],
    meeting_type_code: row['meeting_type_code'],
    expense_type_code: row['expense_type_code']
  )
  
  if fee_type.new_record?
    imported_fee_types += 1
    puts "  FeeType: 导入新记录"
  else
    updated_fee_types += 1
    puts "  FeeType: 更新现有记录"
  end
  
  fee_type.name = row['expense_type_name']
  fee_type.meeting_name = row['meeting_type_name']
  fee_type.save!
  
  # 处理 ProblemType
  problem_type = ProblemType.find_or_initialize_by(
    reimbursement_type_code: row['reimbursement_type_code'],
    meeting_type_code: row['meeting_type_code'],
    expense_type_code: row['expense_type_code'],
    code: row['issue_code']
  )
  
  if problem_type.new_record?
    imported_problem_types += 1
    puts "  ProblemType: 导入新记录"
  else
    updated_problem_types += 1
    puts "  ProblemType: 更新现有记录"
  end
  
  problem_type.title = row['problem_title']
  problem_type.sop_description = row['sop_description']
  problem_type.standard_handling = row['standard_handling']
  problem_type.legacy_problem_code = row['legacy_problem_code']
  problem_type.active = true
  problem_type.save!
end

puts "\n4. 📊 导入结果统计"
puts "-" * 30
puts "FeeType 导入: #{imported_fee_types}, 更新: #{updated_fee_types}"
puts "ProblemType 导入: #{imported_problem_types}, 更新: #{updated_problem_types}"

puts "\n5. 📋 导入后的记录数量"
puts "-" * 30
puts "FeeType 记录数: #{FeeType.count}"
puts "ProblemType 记录数: #{ProblemType.count}"

puts "\n6. 🆔 新导入的记录详情"
puts "-" * 30

puts "新导入的 FeeType 记录:"
FeeType.where(reimbursement_type_code: ['EN', 'MN']).each do |ft|
  puts "  - #{ft.reimbursement_type_code}-#{ft.meeting_type_code}-#{ft.expense_type_code}: #{ft.name}"
end

puts "\n新导入的 ProblemType 记录:"
ProblemType.where(reimbursement_type_code: ['EN', 'MN']).each do |pt|
  puts "  - #{pt.reimbursement_type_code}-#{pt.meeting_type_code}-#{pt.expense_type_code}-#{pt.code}: #{pt.title}"
end

# 清理临时文件
temp_file.unlink

puts "\n" + "=" * 50
puts "🎯 关键发现:"
puts "1. 如果导入的 ProblemType 数量不是4，说明存在验证错误或其他问题"
puts "2. 检查是否有任何验证错误阻止了记录的创建"
puts "3. 对比手动模拟结果与实际服务运行结果的差异"
puts "=" * 50