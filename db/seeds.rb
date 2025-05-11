# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# 只在没有 admin 用户时才创建
if Rails.env.development? && AdminUser.count == 0
  AdminUser.create!(email: 'admin@example.com', password: 'password', password_confirmation: 'password')
end

# 问题类型
problem_types = %w[发票问题 金额问题 材料问题].map { |name| ProblemType.find_or_create_by!(name: name) }

# 问题说明
ProblemDescription.find_or_create_by!(problem_type: problem_types[0], description: '发票抬头错误')
ProblemDescription.find_or_create_by!(problem_type: problem_types[0], description: '发票号码缺失')
ProblemDescription.find_or_create_by!(problem_type: problem_types[1], description: '金额填写错误')
ProblemDescription.find_or_create_by!(problem_type: problem_types[2], description: '材料不全')
ProblemDescription.find_or_create_by!(problem_type: problem_types[2], description: '材料与报销内容不符')

# 补充材料
materials = %w[补充发票 补充合同 补充收据 补充证明].map { |name| Material.find_or_create_by!(name: name) }

# 问题类型-补充材料多对多
ProblemTypeMaterial.find_or_create_by!(problem_type: problem_types[0], material: materials[0])
ProblemTypeMaterial.find_or_create_by!(problem_type: problem_types[2], material: materials[1])
ProblemTypeMaterial.find_or_create_by!(problem_type: problem_types[2], material: materials[2])