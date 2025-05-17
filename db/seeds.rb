# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# 只在没有 admin 用户时才创建
if Rails.env.development? && AdminUser.count == 0
  AdminUser.create!(email: 'admin@example.com', password: 'password', password_confirmation: 'password')
end

# 问题类型
problem_types = %w[发票问题 金额问题].map { |name| ProblemType.find_or_create_by!(name: name) }

# 问题说明
ProblemDescription.find_or_create_by!(problem_type: problem_types[0], description: '发票抬头错误')
ProblemDescription.find_or_create_by!(problem_type: problem_types[0], description: '发票号码缺失')
ProblemDescription.find_or_create_by!(problem_type: problem_types[1], description: '金额填写错误')

# 保留新增的分类数据
# 创建默认的"其他"分类
other_category = DocumentCategory.find_or_create_by!(name: '其他类别') do |cat|
  cat.keywords = ''
  cat.active = true
end

other_problem_type = ProblemType.find_or_create_by!(name: '其他问题') do |pt|
  pt.document_category = other_category
  pt.active = true
end

ProblemDescription.find_or_create_by!(description: '其他描述') do |pd|
  pd.problem_type = other_problem_type
  pd.active = true
end