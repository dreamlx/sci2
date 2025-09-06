#!/usr/bin/env ruby
# 检查数据库索引的脚本

require_relative './config/environment'

puts "🔍 检查 ProblemType 表的索引"
puts "=" * 50

indexes = ActiveRecord::Base.connection.indexes(:problem_types)

puts "找到 #{indexes.length} 个索引:"
indexes.each do |index|
  puts "  索引名: #{index.name}"
  puts "  字段: #{index.columns.join(', ')}"
  puts "  唯一: #{index.unique}"
  puts "  类型: #{index.type}"
  puts
end

puts "🔍 检查数据库中可能存在的重复 code 值"
puts "-" * 30

# 查找所有 code 值及其出现次数
code_counts = ProblemType.group(:code).having('COUNT(*) > 1').count

if code_counts.empty?
  puts "✅ 没有发现重复的 code 值"
else
  puts "⚠️  发现重复的 code 值:"
  code_counts.each do |code, count|
    puts "  '#{code}': 出现 #{count} 次"
  end
end

puts "\n🔍 检查测试数据中的 code 值在数据库中的存在状态"
puts "-" * 30

test_codes = ['01', '02']  # 测试数据中的 issue_code 值

test_codes.each do |code|
  existing_records = ProblemType.where(code: code)
  puts "Code '#{code}': #{existing_records.count} 个记录"
  if existing_records.any?
    existing_records.each do |record|
      puts "  - #{record.reimbursement_type_code}-#{record.meeting_type_code}-#{record.expense_type_code}-#{record.code}: #{record.title}"
    end
  end
end