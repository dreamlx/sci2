# 调试状态异常的报销单
puts "正在查找内部状态为processing但外部状态为已付款的报销单..."

# 查找异常记录
exception_records = Reimbursement.where(status: 'processing', external_status: '已付款')

puts "找到 #{exception_records.count} 条异常记录："

exception_records.each do |reimbursement|
  puts "\n=== 报销单 #{reimbursement.invoice_number} ==="
  puts "内部状态: #{reimbursement.status}"
  puts "外部状态: #{reimbursement.external_status}"
  puts "手动覆盖: #{reimbursement.manual_override?}"
  puts "最后外部状态: #{reimbursement.last_external_status}"
  puts "是否有活跃工单: #{reimbursement.has_active_work_orders?}"
  
  # 测试状态映射逻辑
  expected_status = reimbursement.determine_internal_status_from_external('已付款')
  puts "期望状态: #{expected_status}"
  
  # 检查工单情况
  work_orders = reimbursement.work_orders
  puts "工单数量: #{work_orders.count}"
  work_orders.each do |wo|
    puts "  - 工单 #{wo.id}: 类型=#{wo.type}, 状态=#{wo.status}"
  end
end

puts "\n=== 统计信息 ==="
puts "总报销单数: #{Reimbursement.count}"
puts "外部状态为已付款的总数: #{Reimbursement.where(external_status: '已付款').count}"
puts "内部状态为closed的总数: #{Reimbursement.where(status: 'closed').count}"
puts "手动覆盖的总数: #{Reimbursement.where(manual_override: true).count}"