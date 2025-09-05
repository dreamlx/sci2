# 临时调试脚本 - 检查方法重复定义
puts "=== 检查 FeeType 相关方法定义 ==="

# 检查 Admin::FeeTypesController 的方法
if defined?(Admin::FeeTypesController)
  controller = Admin::FeeTypesController
  puts "Admin::FeeTypesController 存在"
  puts "实例方法: #{controller.instance_methods(false).grep(/index/)}"
  puts "所有实例方法中包含index的: #{controller.instance_methods.grep(/index/)}"
else
  puts "Admin::FeeTypesController 不存在"
end

puts "\n=== 检查 ProblemType 相关方法定义 ==="

# 检查 Admin::ProblemTypesController 的方法
if defined?(Admin::ProblemTypesController)
  controller = Admin::ProblemTypesController
  puts "Admin::ProblemTypesController 存在"
  puts "实例方法: #{controller.instance_methods(false).grep(/index/)}"
  puts "所有实例方法中包含index的: #{controller.instance_methods.grep(/index/)}"
else
  puts "Admin::ProblemTypesController 不存在"
end

puts "\n=== 检查 ActiveAdmin 资源 ==="
puts "ActiveAdmin 注册的资源:"
ActiveAdmin.application.namespaces[:admin].resources.each do |resource|
  if resource.resource_class_name.in?(['FeeType', 'ProblemType'])
    puts "资源: #{resource.resource_class_name}"
    puts "控制器: #{resource.controller_name}"
    puts "控制器类: #{resource.controller.name}"
  end
end