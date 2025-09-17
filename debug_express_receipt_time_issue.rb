#!/usr/bin/env ruby
# 调试快递收单时间问题

require_relative './config/environment'

puts "=== 快递收单时间问题调试脚本 ==="
puts

# 模拟不同的CSV数据格式
test_cases = [
  {
    name: "标准格式（新列名）",
    row_data: ['单据编号', '操作意见', '操作时间', 'Filling ID'],
    test_row: ['R202501001', '快递单号: SF1001', '2025-01-01 10:00:00', '2025010001']
  },
  {
    name: "旧格式（旧列名）",
    row_data: ['单号', '操作意见', '操作时间'],
    test_row: ['R202501001', '快递单号: SF1001', '2025-01-01 10:00:00']
  },
  {
    name: "无Filling ID格式",
    row_data: ['单据编号', '操作意见', '操作时间'],
    test_row: ['R202501001', '快递单号: SF1001', '2025-01-01 10:00:00']
  },
  {
    name: "时间格式不同",
    row_data: ['单据编号', '操作意见', '操作时间', 'Filling ID'],
    test_row: ['R202501001', '快递单号: SF1001', '2025/01/01 10:00', '2025010001']
  },
  {
    name: "时间为空",
    row_data: ['单据编号', '操作意见', '操作时间', 'Filling ID'],
    test_row: ['R202501001', '快递单号: SF1001', '', '2025010001']
  },
  {
    name: "用户实际格式",
    row_data: ['序号', '单据类型', '单号', '申请人', '操作时间', '操作类型', '操作意见'],
    test_row: ['1', '学术会议报销单', 'ER23624366', '徐洋', '2025-08-08 15:42:02', '单据接收', '快递单号：SF0286361042523']
  }
]

# 创建测试用的admin user
admin_user = AdminUser.first || create(:admin_user)

# 测试每个用例
test_cases.each_with_index do |test_case, index|
  puts "测试用例 #{index + 1}: #{test_case[:name]}"
  puts "CSV列头: #{test_case[:row_data].inspect}"
  puts "测试行: #{test_case[:test_row].inspect}"
  
  # 模拟CSV行数据
  row = {}
  test_case[:row_data].each_with_index do |header, i|
    row[header] = test_case[:test_row][i]
  end
  
  puts "解析后的行数据: #{row.inspect}"
  
  # 测试时间解析
  received_at_str = row['操作时间']
  puts "操作时间字符串: #{received_at_str.inspect}"
  
  # 使用ExpressReceiptImportService的parse_datetime方法
  service = ExpressReceiptImportService.new(nil, admin_user)
  parsed_time = service.send(:parse_datetime, received_at_str)
  
  puts "解析后的时间: #{parsed_time.inspect}"
  
  # 模拟实际使用逻辑
  received_at = parsed_time || Time.current
  puts "最终使用的时间: #{received_at.inspect}"
  
  # 检查是否使用了当前时间
  if received_at.nil?
    puts "⚠️  警告：时间为nil！"
  elsif (received_at.to_time - Time.current).abs < 5 # 5秒内认为是当前时间
    puts "⚠️  警告：使用了当前时间而不是文件中的时间！"
    puts "   原因：时间解析失败或时间为空"
  else
    puts "✅ 正确：使用了文件中的时间"
  end
  
  puts "----------------------------------------"
  puts
end

puts "=== 检查最近创建的ExpressReceiptWorkOrder记录 ==="
puts

# 检查最近创建的记录，看时间是否有问题
recent_work_orders = ExpressReceiptWorkOrder.where('created_at > ?', Time.current - 2.days).order(created_at: :desc).limit(5)

recent_work_orders.each do |wo|
  puts "工单ID: #{wo.id}"
  puts "填充ID: #{wo.filling_id}"
  puts "快递单号: #{wo.tracking_number}"
  puts "收单时间: #{wo.received_at}"
  puts "创建时间: #{wo.created_at}"
  puts "时间差: #{(wo.received_at - wo.created_at).abs}秒"
  
  # 检查收单时间是否接近创建时间（可能表示使用了默认值）
  if (wo.received_at - wo.created_at).abs < 60 # 60秒内
    puts "⚠️  警告：收单时间接近创建时间，可能使用了默认值"
  else
    puts "✅ 收单时间与创建时间差异正常"
  end
  
  puts "----------------------------------------"
end

puts "=== 调试完成 ==="