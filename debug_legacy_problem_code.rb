#!/usr/bin/env ruby
# 调试脚本：验证 legacy_problem_code 虚拟字段假设

require_relative './config/environment'

puts "🔍 Legacy Problem Code 虚拟字段假设验证"
puts "=" * 50

# 1. 检查当前数据库结构
puts "\n1. 📊 检查数据库结构"
puts "-" * 30

# 检查 problem_types 表结构
if ActiveRecord::Base.connection.table_exists?(:problem_types)
  columns = ActiveRecord::Base.connection.columns(:problem_types)
  puts "ProblemTypes 表字段:"
  columns.each do |col|
    puts "  - #{col.name}: #{col.type}"
  end
else
  puts "❌ problem_types 表不存在"
end

# 2. 分析测试数据中的重复问题
puts "\n2. 🔄 分析测试数据重复问题"
puts "-" * 30

# 模拟测试数据
test_data = [
  { reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01', name: '月度交通费' },
  { reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01', name: '月度交通费' }, # 重复
  { reimbursement_type_code: 'MN', meeting_type_code: '01', expense_type_code: '01', name: '会议讲课费' },
  { reimbursement_type_code: 'MN', meeting_type_code: '01', expense_type_code: '00', name: '通用' }
]

puts "测试数据中的 FeeType 组合键："
unique_combinations = {}
test_data.each_with_index do |data, index|
  key = "#{data[:reimbursement_type_code]}-#{data[:meeting_type_code]}-#{data[:expense_type_code]}"
  if unique_combinations[key]
    puts "  🔄 行 #{index + 1}: #{key} (重复)"
  else
    puts "  ✅ 行 #{index + 1}: #{key}"
    unique_combinations[key] = true
  end
end

puts "\n预期创建的 FeeType 记录数: #{unique_combinations.length}"

# 3. 验证 legacy_problem_code 虚拟字段逻辑
puts "\n3. 🧮 验证 legacy_problem_code 虚拟字段逻辑"
puts "-" * 30

# 模拟 ProblemType 测试数据
problem_test_data = [
  { reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01', code: '01', legacy_problem_code: 'EN000101' },
  { reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01', code: '02', legacy_problem_code: 'EN000102' },
  { reimbursement_type_code: 'MN', meeting_type_code: '01', expense_type_code: '01', code: '01', legacy_problem_code: 'MN010101' },
  { reimbursement_type_code: 'MN', meeting_type_code: '01', expense_type_code: '00', code: '01', legacy_problem_code: 'MN010001' }
]

puts "ProblemType 虚拟字段验证："
problem_test_data.each_with_index do |data, index|
  calculated_legacy = "#{data[:reimbursement_type_code]}#{data[:meeting_type_code].rjust(2, '0')}#{data[:expense_type_code].rjust(2, '0')}#{data[:code]}"
  actual_legacy = data[:legacy_problem_code]
  
  if calculated_legacy == actual_legacy
    puts "  ✅ 行 #{index + 1}: #{calculated_legacy} (匹配)"
  else
    puts "  ❌ 行 #{index + 1}: 计算=#{calculated_legacy}, 实际=#{actual_legacy} (不匹配)"
  end
end

# 4. 检查当前数据库中的数据
puts "\n4. 🗄️ 检查当前数据库中的数据"
puts "-" * 30

puts "当前 FeeType 记录数: #{FeeType.count}"
puts "当前 ProblemType 记录数: #{ProblemType.count}"

if FeeType.any?
  puts "\nFeeType 记录："
  FeeType.all.each do |ft|
    puts "  - #{ft.reimbursement_type_code}-#{ft.meeting_type_code}-#{ft.expense_type_code}: #{ft.name}"
  end
end

if ProblemType.any?
  puts "\nProblemType 记录（前10条）："
  ProblemType.limit(10).each do |pt|
    if pt.reimbursement_type_code && pt.meeting_type_code && pt.expense_type_code && pt.code
      calculated_legacy = "#{pt.reimbursement_type_code}#{pt.meeting_type_code.rjust(2, '0')}#{pt.expense_type_code.rjust(2, '0')}#{pt.code}"
      puts "  - #{pt.title}: 存储=#{pt.legacy_problem_code}, 计算=#{calculated_legacy}"
    else
      puts "  - #{pt.title}: 字段不完整，跳过计算"
    end
  end
end

# 5. 分析导入服务逻辑
puts "\n5. 📥 分析导入服务逻辑"
puts "-" * 30

# 模拟导入服务的行为
puts "模拟导入 CSV 数据："
csv_data = [
  { 
    reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01', name: '月度交通费',
    problem_code: '01', problem_title: '燃油费行程问题', legacy_problem_code: 'EN000101'
  },
  { 
    reimbursement_type_code: 'EN', meeting_type_code: '00', expense_type_code: '01', name: '月度交通费',
    problem_code: '02', problem_title: '出租车行程问题', legacy_problem_code: 'EN000102'
  },
  { 
    reimbursement_type_code: 'MN', meeting_type_code: '01', expense_type_code: '01', name: '会议讲课费',
    problem_code: '01', problem_title: '非讲者库讲者', legacy_problem_code: 'MN010101'
  },
  { 
    reimbursement_type_code: 'MN', meeting_type_code: '01', expense_type_code: '00', name: '通用',
    problem_code: '01', problem_title: '会议权限问题', legacy_problem_code: 'MN010001'
  }
]

fee_type_actions = []
problem_type_actions = []

csv_data.each_with_index do |row, index|
  # 模拟 FeeType 处理
  fee_type_key = "#{row[:reimbursement_type_code]}-#{row[:meeting_type_code]}-#{row[:expense_type_code]}"
  if fee_type_actions.none? { |action| action[:key] == fee_type_key }
    fee_type_actions << { key: fee_type_key, action: :imported, row: index + 1 }
  else
    fee_type_actions << { key: fee_type_key, action: :updated, row: index + 1 }
  end
  
  # 模拟 ProblemType 处理
  problem_type_key = "#{row[:reimbursement_type_code]}-#{row[:meeting_type_code]}-#{row[:expense_type_code]}-#{row[:problem_code]}"
  if problem_type_actions.none? { |action| action[:key] == problem_type_key }
    problem_type_actions << { key: problem_type_key, action: :imported, row: index + 1 }
  else
    problem_type_actions << { key: problem_type_key, action: :updated, row: index + 1 }
  end
end

puts "\nFeeType 处理结果："
fee_type_actions.each do |action|
  puts "  行 #{action[:row]}: #{action[:key]} -> #{action[:action]}"
end

puts "\nProblemType 处理结果："
problem_type_actions.each do |action|
  puts "  行 #{action[:row]}: #{action[:key]} -> #{action[:action]}"
end

imported_fee_types = fee_type_actions.count { |a| a[:action] == :imported }
imported_problem_types = problem_type_actions.count { |a| a[:action] == :imported }

puts "\n预期导入结果："
puts "  FeeType 导入数量: #{imported_fee_types}"
puts "  ProblemType 导入数量: #{imported_problem_types}"

puts "\n" + "=" * 50
puts "🎯 关键发现："
puts "1. 如果 FeeType 导入数量为 3，说明存在重复的上下文组合"
puts "2. 如果 ProblemType 导入数量为 4，说明所有问题类型都是唯一的"
puts "3. Legacy Problem Code 虚拟字段逻辑应该能够正确计算"
puts "=" * 50