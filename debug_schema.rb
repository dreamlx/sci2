#!/usr/bin/env ruby

# 调试脚本：验证数据库结构和字段问题
require_relative './config/environment'

puts "=== 数据库 Schema 验证 ==="
puts

# 检查 FeeType 表结构
puts "1. FeeType 表结构:"
begin
  columns = ActiveRecord::Base.connection.columns(:fee_types)
  puts "   存在的列: #{columns.map(&:name).inspect}"
  
  # 检查特定字段是否存在
  code_exists = columns.any? { |c| c.name == 'code' }
  title_exists = columns.any? { |c| c.name == 'title' }
  name_exists = columns.any? { |c| c.name == 'name' }
  meeting_type_exists = columns.any? { |c| c.name == 'meeting_type' }
  meeting_name_exists = columns.any? { |c| c.name == 'meeting_name' }
  
  puts "   code 字段存在: #{code_exists}"
  puts "   title 字段存在: #{title_exists}"
  puts "   name 字段存在: #{name_exists}"
  puts "   meeting_type 字段存在: #{meeting_type_exists}"
  puts "   meeting_name 字段存在: #{meeting_name_exists}"
  
  # 检查新字段
  new_fields = ['reimbursement_type_code', 'meeting_type_code', 'expense_type_code']
  new_fields.each do |field|
    exists = columns.any? { |c| c.name == field }
    puts "   #{field} 字段存在: #{exists}"
  end
rescue => e
  puts "   错误: #{e.message}"
end
puts

# 检查 ProblemType 表结构
puts "2. ProblemType 表结构:"
begin
  columns = ActiveRecord::Base.connection.columns(:problem_types)
  puts "   存在的列: #{columns.map(&:name).inspect}"
  
  # 检查关联字段
  fee_type_id_exists = columns.any? { |c| c.name == 'fee_type_id' }
  puts "   fee_type_id 字段存在: #{fee_type_id_exists}"
  
  # 检查新字段
  new_fields = ['reimbursement_type_code', 'meeting_type_code', 'expense_type_code']
  new_fields.each do |field|
    exists = columns.any? { |c| c.name == field }
    puts "   #{field} 字段存在: #{exists}"
  end
rescue => e
  puts "   错误: #{e.message}"
end
puts

# 尝试使用旧结构创建 FeeType 记录
puts "3. 测试旧结构创建 FeeType:"
begin
  # 这应该会失败
  old_fee_type = FeeType.create!(
    code: "00",
    title: "月度交通费",
    meeting_type: "个人",
    active: true
  )
  puts "   意外成功: 用旧结构创建了 FeeType"
rescue ActiveRecord::UnknownAttributeError => e
  puts "   预期失败 - 未知字段: #{e.message}"
rescue ActiveRecord::StatementInvalid => e
  puts "   预期失败 - 数据库错误: #{e.message}"
rescue => e
  puts "   其他错误: #{e.message}"
end
puts

# 尝试使用新结构创建 FeeType 记录
puts "4. 测试新结构创建 FeeType:"
begin
  new_fee_type = FeeType.create!(
    reimbursement_type_code: "EN",
    meeting_type_code: "00",
    expense_type_code: "01",
    name: "月度交通费",
    meeting_name: "个人",
    active: true
  )
  puts "   成功: 用新结构创建了 FeeType (id: #{new_fee_type.id})"
rescue => e
  puts "   失败: #{e.message}"
end
puts

# 尝试使用旧结构创建 ProblemType 记录
puts "5. 测试旧结构创建 ProblemType:"
begin
  # 首先创建一个 FeeType 用于关联
  fee_type = FeeType.create!(
    reimbursement_type_code: "EN",
    meeting_type_code: "00",
    expense_type_code: "01",
    name: "月度交通费",
    meeting_name: "个人",
    active: true
  )
  
  # 尝试用旧结构创建 ProblemType
  old_problem_type = ProblemType.create!(
    code: "01",
    title: "燃油费行程问题",
    sop_description: "测试",
    standard_handling: "测试",
    fee_type: fee_type,
    active: true
  )
  puts "   意外成功: 用旧结构创建了 ProblemType"
rescue ActiveRecord::UnknownAttributeError => e
  puts "   预期失败 - 未知字段: #{e.message}"
rescue ActiveRecord::StatementInvalid => e
  puts "   预期失败 - 数据库错误: #{e.message}"
rescue => e
  puts "   其他错误: #{e.message}"
end
puts

# 尝试使用新结构创建 ProblemType 记录
puts "6. 测试新结构创建 ProblemType:"
begin
  new_problem_type = ProblemType.create!(
    reimbursement_type_code: "EN",
    meeting_type_code: "00",
    expense_type_code: "01",
    code: "01",
    title: "燃油费行程问题",
    sop_description: "测试",
    standard_handling: "测试",
    active: true
  )
  puts "   成功: 用新结构创建了 ProblemType (id: #{new_problem_type.id})"
rescue => e
  puts "   失败: #{e.message}"
end

puts
puts "=== 验证完成 ==="