#!/usr/bin/env ruby

# 测试导出权限的诊断脚本
require_relative 'config/environment'

puts "=== ActiveAdmin 导出权限诊断 ==="
puts

# 获取当前用户
admin_user = AdminUser.find(11)
puts "当前用户: #{admin_user.email} (角色: #{admin_user.role})"

# 测试 Ability
ability = Ability.new(admin_user)
puts "Ability 初始化完成"

# 测试各种权限
puts "\n=== 权限测试结果 ==="

# 基本权限
puts "can :read, Reimbursement: #{ability.can?(:read, Reimbursement)}"
puts "can :export, Reimbursement: #{ability.can?(:export, Reimbursement)}"
puts "can :download, Reimbursement: #{ability.can?(:download, Reimbursement)}"
puts "can :manage, :all: #{ability.can?(:manage, :all)}"

# 具体实例权限
reimbursement = Reimbursement.first
if reimbursement
  puts "\n=== 具体实例权限 ==="
  puts "can :read, Reimbursement实例: #{ability.can?(:read, reimbursement)}"
  puts "can :export, Reimbursement实例: #{ability.can?(:export, reimbursement)}"
end

# 测试 ActiveAdmin 配置
puts "\n=== ActiveAdmin 配置 ==="
puts "下载链接配置: #{ActiveAdmin.application.namespaces[:admin].download_links.inspect}"

# 测试路由
puts "\n=== 路由测试 ==="
begin
  # 模拟一个导出请求
  puts "尝试访问 /admin/reimbursements.xlsx 的路由..."
  
  # 检查是否有对应的路由
  route = Rails.application.routes.routes.find do |route|
    route.path.spec.to_s.include?('admin/reimbursements') && route.defaults[:format] == :xlsx
  end
  
  if route
    puts "找到路由: #{route.path.spec}"
    puts "控制器: #{route.defaults[:controller]}"
    puts "动作: #{route.defaults[:action]}"
  else
    puts "未找到 .xlsx 格式的路由"
  end
rescue => e
  puts "路由测试出错: #{e.message}"
end

puts "\n=== 诊断完成 ==="
