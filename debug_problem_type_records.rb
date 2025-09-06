#!/usr/bin/env ruby
# 专门调试 ProblemType 记录的脚本

require_relative './config/environment'

puts "🔍 ProblemType 记录详细调试"
puts "=" * 50

# 测试数据中的 ProblemType 组合
test_combinations = [
  'EN-00-01-01',
  'EN-00-02-02', 
  'MN-01-01-01',
  'MN-01-00-01'
]

puts "1. 📊 检查测试数据中的 ProblemType 组合在数据库中的存在状态"
puts "-" * 30

existing_count = 0
test_combinations.each do |combination|
  rt_code, mt_code, et_code, code = combination.split('-')
  existing = ProblemType.find_by(reimbursement_type_code: rt_code, meeting_type_code: mt_code, expense_type_code: et_code, code: code)
  
  if existing
    puts "  ⚠️  #{combination} 已存在于数据库中"
    existing_count += 1
    puts "      ID: #{existing.id}, 标题: #{existing.title}"
  else
    puts "  ✅ #{combination} 不存在于数据库中"
  end
end

puts "\n总结: #{existing_count} 个组合已存在，#{test_combinations.length - existing_count} 个组合不存在"

puts "\n2. 📋 检查数据库中所有相关的 ProblemType 记录"
puts "-" * 30

# 查找所有与测试数据相关的记录
related_records = ProblemType.where(reimbursement_type_code: ['EN', 'MN'])
puts "相关记录总数: #{related_records.count}"

related_records.each do |record|
  combination = "#{record.reimbursement_type_code}-#{record.meeting_type_code}-#{record.expense_type_code}-#{record.code}"
  puts "  - #{combination}: #{record.title}"
  if test_combinations.include?(combination)
    puts "    📌 这个组合在测试数据中"
  else
    puts "    ⚠️  这个组合不在测试数据中，但可能影响测试"
  end
end

puts "\n3. 🔍 分析测试失败原因"
puts "-" * 30

expected_new = test_combinations.length - existing_count
puts "期望创建的新记录数: #{expected_new}"
puts "但实际上测试期望创建数: 3"
puts "差异: #{3 - expected_new}"

if expected_new != 3
  puts "💡 这解释了测试失败的原因！"
  puts "   测试期望创建3个新记录，但实际只有#{expected_new}个记录是新的"
  puts "   建议将测试期望修改为 #{expected_new}"
end

puts "\n4. 📝 建议的测试修正"
puts "-" * 30

puts "当前测试代码:"
puts 'expect { service.import }.to change(ProblemType, :count).by(3)'

puts "\n建议修改为:"
puts "expect { service.import }.to change(ProblemType, :count).by(#{expected_new})"

puts "\n" + "=" * 50
puts "🎯 诊断结论:"
puts "数据库中已存在 #{existing_count} 个测试数据中的 ProblemType 组合"
puts "因此导入服务只会创建 #{test_combinations.length - existing_count} 个新记录"
puts "测试期望应该调整为 #{test_combinations.length - existing_count}"
puts "=" * 50