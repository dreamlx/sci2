#!/usr/bin/env ruby
# 可选：修复 AdminUser 数据中的空 name 字段

puts '=== 修复 AdminUser 数据 ==='
puts "时间: #{Time.current}"
puts

# 查找并修复有问题的用户数据
puts '1. 查找需要修复的用户:'

problem_users = AdminUser.where("name IS NULL OR name = ''")
puts "  发现 #{problem_users.count} 个需要修复的用户"

if problem_users.any?
  puts "\n2. 修复用户数据:"

  problem_users.each do |user|
    puts "  修复用户 ID #{user.id}:"
    puts "    修复前: name=#{user.name.inspect}, email=#{user.email.inspect}"

    # 从 email 中提取用户名作为 name
    if user.email.present?
      # 提取 email 的用户名部分
      username = user.email.split('@').first
      # 格式化用户名（首字母大写）
      formatted_name = username.split('.').map(&:capitalize).join(' ')

      user.update!(name: formatted_name)
      puts "    修复后: name=#{user.name.inspect}"
    else
      # 如果连 email 都没有，使用默认名称
      user.update!(name: "用户 ##{user.id}")
      puts "    修复后: name=#{user.name.inspect}"
    end
  end

  puts "\n3. 验证修复结果:"
  remaining_problems = AdminUser.where("name IS NULL OR name = ''")
  if remaining_problems.empty?
    puts '  ✅ 所有用户数据已修复'
  else
    puts "  ❌ 仍有 #{remaining_problems.count} 个用户需要修复"
  end

else
  puts '  ✅ 没有需要修复的用户'
end

puts "\n=== 数据修复完成 ==="
