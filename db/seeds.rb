# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# 只在没有 admin 用户时才创建
if Rails.env.development? && AdminUser.count == 0
  AdminUser.create!(email: 'admin@example.com', password: 'password', password_confirmation: 'password')
end

# 创建费用类型
fee_type_1 = FeeType.find_or_create_by!(code: 'FT001', name: '交通费') do |ft|
  ft.active = true
end

fee_type_2 = FeeType.find_or_create_by!(code: 'FT002', name: '餐饮费') do |ft|
  ft.active = true
end

# 创建问题类型
ProblemType.find_or_create_by!(code: 'PT001', name: '发票问题') do |pt|
  pt.fee_type = fee_type_1
  pt.active = true
end

ProblemType.find_or_create_by!(code: 'PT002', name: '金额错误') do |pt|
  pt.fee_type = fee_type_1
  pt.active = true
end

ProblemType.find_or_create_by!(code: 'PT003', name: '费用类型错误') do |pt|
  pt.fee_type = fee_type_2
  pt.active = true
end

ProblemType.find_or_create_by!(code: 'PT004', name: '其他问题') do |pt|
  pt.fee_type = fee_type_2
  pt.active = true
end