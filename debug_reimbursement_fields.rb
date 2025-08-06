# 调试脚本：检查报销单字段的实际值
puts "=== 报销单字段调试分析 ==="
puts "时间: #{Time.current}"
puts

# 检查前10条记录的字段值
reimbursements = Reimbursement.limit(10)

puts "检查前10条报销单记录的关键字段值："
puts "-" * 80

reimbursements.each_with_index do |r, index|
  puts "记录 #{index + 1}: #{r.invoice_number}"
  puts "  当前审批节点 (erp_current_approval_node): #{r.erp_current_approval_node.inspect}"
  puts "  当前审批节点转入时间 (erp_node_entry_time): #{r.erp_node_entry_time.inspect}"
  puts "  报销单审核通过日期 (approval_date): #{r.approval_date.inspect}"
  puts "  数据库原始值类型:"
  puts "    - erp_current_approval_node: #{r.erp_current_approval_node.class}"
  puts "    - erp_node_entry_time: #{r.erp_node_entry_time.class}"
  puts "    - approval_date: #{r.approval_date.class}"
  puts
end

puts "=== 统计分析 ==="
total_count = Reimbursement.count
nil_approval_node_count = Reimbursement.where(erp_current_approval_node: nil).count
nil_node_entry_time_count = Reimbursement.where(erp_node_entry_time: nil).count
nil_approval_date_count = Reimbursement.where(approval_date: nil).count

puts "总记录数: #{total_count}"
puts "当前审批节点为空的记录数: #{nil_approval_node_count} (#{(nil_approval_node_count.to_f / total_count * 100).round(2)}%)"
puts "当前审批节点转入时间为空的记录数: #{nil_node_entry_time_count} (#{(nil_node_entry_time_count.to_f / total_count * 100).round(2)}%)"
puts "报销单审核通过日期为空的记录数: #{nil_approval_date_count} (#{(nil_approval_date_count.to_f / total_count * 100).round(2)}%)"

puts "\n=== ActiveAdmin显示逻辑测试 ==="
test_record = reimbursements.first
puts "测试记录: #{test_record.invoice_number}"
puts "ActiveAdmin显示逻辑模拟:"
puts "  当前审批节点显示: #{test_record.erp_current_approval_node || '0'}"
puts "  当前审批节点转入时间显示: #{test_record.erp_node_entry_time&.strftime('%Y-%m-%d %H:%M:%S') || '0'}"
puts "  报销单审核通过日期显示: #{test_record.approval_date&.strftime('%Y-%m-%d %H:%M:%S') || '0'}"

puts "\n=== 推荐的显示逻辑 ==="
puts "  当前审批节点显示: #{test_record.erp_current_approval_node || '-'}"
puts "  当前审批节点转入时间显示: #{test_record.erp_node_entry_time&.strftime('%Y-%m-%d %H:%M:%S') || '-'}"
puts "  报销单审核通过日期显示: #{test_record.approval_date&.strftime('%Y-%m-%d') || '-'}"