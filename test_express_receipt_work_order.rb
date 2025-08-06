#!/usr/bin/env ruby
# ExpressReceiptWorkOrder 测试脚本
# 使用方法: rails runner test_express_receipt_work_order.rb

puts '=== ExpressReceiptWorkOrder 测试 ==='
puts

# 测试 1: 基本 ExpressReceiptWorkOrder 创建
puts '1. 测试基本 ExpressReceiptWorkOrder 创建...'
begin
  # 查找或创建测试报销单
  reimbursement = Reimbursement.find_or_create_by(invoice_number: 'TEST_R001') do |r|
    r.applicant = 'Test User'
    r.department = 'Test Department'
    r.amount = 1000.0
    r.status = 'pending'
    r.is_electronic = true
  end
  puts "   使用报销单: #{reimbursement.id} (#{reimbursement.invoice_number})"
  
  # 测试 ExpressReceiptWorkOrder 创建（不显式设置状态）
  express_work_order = ExpressReceiptWorkOrder.create!(
    reimbursement: reimbursement,
    tracking_number: 'TEST_TRACK_001',
    received_at: Time.current,
    created_by: 1
  )
  
  puts "   ✅ ExpressReceiptWorkOrder 创建成功: #{express_work_order.id}"
  puts "   状态: #{express_work_order.status}"
  puts "   快递单号: #{express_work_order.tracking_number}"
  puts "   类型: #{express_work_order.type}"
  
rescue => e
  puts "   ❌ 错误: #{e.message}"
  puts "   堆栈: #{e.backtrace.first(3).join("\n   ")}"
end

puts

# 测试 2: 回调执行验证
puts '2. 测试回调执行...'
begin
  reimbursement = Reimbursement.first
  initial_notification_status = reimbursement.last_viewed_express_receipts_at
  puts "   初始通知状态: #{initial_notification_status || 'nil'}"
  
  express_work_order = ExpressReceiptWorkOrder.create!(
    reimbursement: reimbursement,
    tracking_number: 'TEST_TRACK_002',
    received_at: Time.current,
    created_by: 1
  )
  
  # 检查回调是否执行
  reimbursement.reload
  final_notification_status = reimbursement.last_viewed_express_receipts_at
  puts "   最终通知状态: #{final_notification_status || 'nil'}"
  puts "   通知状态已改变: #{initial_notification_status != final_notification_status}"
  
  # 检查 WorkOrderOperation 创建
  operation = express_work_order.operations.first
  if operation
    puts "   ✅ WorkOrderOperation 已创建: #{operation.operation_type}"
  else
    puts "   ⚠️  未找到 WorkOrderOperation"
  end
  
rescue => e
  puts "   ❌ 错误: #{e.message}"
end

puts

# 测试 3: 快递收单导入服务模拟
puts '3. 测试 ExpressReceiptImportService 集成...'
begin
  # 创建模拟 CSV 导入的测试数据
  test_row = {
    '单据编号' => 'TEST_R002',
    '快递单号' => 'SF_TEST_123',
    '操作时间' => '2025-01-15 14:30:00'
  }
  
  # 为测试创建报销单
  test_reimbursement = Reimbursement.find_or_create_by(invoice_number: 'TEST_R002') do |r|
    r.applicant = 'Import Test User'
    r.department = 'Import Test Dept'
    r.amount = 2000.0
    r.status = 'pending'
    r.is_electronic = true
  end
  
  puts "   使用报销单: #{test_reimbursement.id} (#{test_reimbursement.invoice_number})"
  
  # 模拟导入服务逻辑
  document_number = test_row['单据编号']
  tracking_number = test_row['快递单号']
  received_at_str = test_row['操作时间']
  
  # 解析日期时间（简化版本）
  received_at = Time.parse(received_at_str) rescue Time.current
  
  # 检查重复
  existing = ExpressReceiptWorkOrder.exists?(
    reimbursement_id: test_reimbursement.id, 
    tracking_number: tracking_number
  )
  
  if existing
    puts "   ⚠️  发现重复，跳过..."
  else
    # 像导入服务一样创建 ExpressReceiptWorkOrder
    work_order = ExpressReceiptWorkOrder.new(
      reimbursement: test_reimbursement,
      status: 'completed',
      tracking_number: tracking_number,
      received_at: received_at,
      created_by: 1
    )
    
    if work_order.save
      puts "   ✅ 导入模拟成功: #{work_order.id}"
      puts "   状态: #{work_order.status}"
      puts "   快递单号: #{work_order.tracking_number}"
      
      # 检查报销单更新
      test_reimbursement.reload
      puts "   报销单状态: #{test_reimbursement.status}"
    else
      puts "   ❌ 导入模拟失败: #{work_order.errors.full_messages.join(', ')}"
    end
  end
  
rescue => e
  puts "   ❌ 错误: #{e.message}"
  puts "   堆栈: #{e.backtrace.first(3).join("\n   ")}"
end

puts

# 测试 4: 验证修复的状态回调
puts '4. 测试状态回调修复...'
begin
  # 创建一个新的 ExpressReceiptWorkOrder，不设置状态
  reimbursement = Reimbursement.first
  work_order = ExpressReceiptWorkOrder.new(
    reimbursement: reimbursement,
    tracking_number: 'TEST_CALLBACK_001',
    received_at: Time.current,
    created_by: 1
  )
  
  puts "   保存前状态: #{work_order.status || 'nil'}"
  
  # 触发验证和回调
  work_order.valid?
  puts "   验证后状态: #{work_order.status}"
  
  if work_order.save
    puts "   ✅ 保存成功，最终状态: #{work_order.status}"
    puts "   状态回调修复验证: #{work_order.status == 'completed' ? '✅ 成功' : '❌ 失败'}"
  else
    puts "   ❌ 保存失败: #{work_order.errors.full_messages.join(', ')}"
  end
  
rescue => e
  puts "   ❌ 错误: #{e.message}"
end

puts
puts '=== 测试总结 ==='
total_express_orders = ExpressReceiptWorkOrder.count
puts "总 ExpressReceiptWorkOrders: #{total_express_orders}"
puts '测试完成。'