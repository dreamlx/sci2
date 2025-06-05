# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# 只在没有 admin 用户时才创建
if Rails.env.development? && AdminUser.count == 0
  AdminUser.create!(email: 'admin@example.com', password: 'password', password_confirmation: 'password')
end

# 创建费用类型
fee_type_1 = FeeType.find_or_create_by!(code: 'FT001', title: '交通费') do |ft|
  ft.active = true
  ft.meeting_type = '个人'
end

fee_type_2 = FeeType.find_or_create_by!(code: 'FT002', title: '餐饮费') do |ft|
  ft.active = true
  ft.meeting_type = '个人'
end

# 添加会议讲课费类型
fee_type_3 = FeeType.find_or_create_by!(code: 'FT003', title: '会议讲课费') do |ft|
  ft.active = true
  ft.meeting_type = '学术论坛'
end

# 创建问题类型
ProblemType.find_or_create_by!(code: 'PT001', title: '发票问题') do |pt|
  pt.fee_type = fee_type_1
  pt.active = true
  pt.sop_description = '发票信息不完整或有误'
  pt.standard_handling = '要求提供正确的发票'
end

ProblemType.find_or_create_by!(code: 'PT002', title: '金额错误') do |pt|
  pt.fee_type = fee_type_1
  pt.active = true
  pt.sop_description = '报销金额与实际金额不符'
  pt.standard_handling = '核对金额并更正'
end

ProblemType.find_or_create_by!(code: 'PT003', title: '费用类型错误') do |pt|
  pt.fee_type = fee_type_2
  pt.active = true
  pt.sop_description = '费用类型选择错误'
  pt.standard_handling = '更正为正确的费用类型'
end

ProblemType.find_or_create_by!(code: 'PT004', title: '其他问题') do |pt|
  pt.fee_type = fee_type_2
  pt.active = true
  pt.sop_description = '其他未列出的问题'
  pt.standard_handling = '根据具体情况处理'
end

# 添加与会议讲课费相关的问题类型
ProblemType.find_or_create_by!(code: 'PT005', title: '讲课费发票问题') do |pt|
  pt.fee_type = fee_type_3
  pt.active = true
  pt.sop_description = '讲课费发票信息不完整或有误'
  pt.standard_handling = '要求提供正确的讲课费发票'
end

ProblemType.find_or_create_by!(code: 'PT006', title: '讲课费金额错误') do |pt|
  pt.fee_type = fee_type_3
  pt.active = true
  pt.sop_description = '讲课费金额与实际不符'
  pt.standard_handling = '核对讲课费金额并更正'
end