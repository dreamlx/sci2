# 分析报销单状态分布
puts "=== 报销单状态分布分析 ==="

puts "\n1. 按内部状态分组："
Reimbursement.group(:status).count.each do |status, count|
  puts "  #{status}: #{count}"
end

puts "\n2. 按外部状态分组（前10个）："
Reimbursement.group(:external_status).count.sort_by { |k, v| -v }.first(10).each do |status, count|
  puts "  #{status}: #{count}"
end

puts "\n3. 外部状态为'已付款'或'待付款'的记录："
paid_statuses = ['已付款', '待付款']
paid_records = Reimbursement.where(external_status: paid_statuses)
puts "  总数: #{paid_records.count}"

paid_records.group(:status).count.each do |internal_status, count|
  puts "    内部状态 #{internal_status}: #{count}"
end

puts "\n4. 检查是否还有其他异常情况："
# 查找外部状态为已付款/待付款但内部状态不是closed的记录
exceptions = Reimbursement.where(external_status: paid_statuses).where.not(status: 'closed')
puts "  外部状态为已付款/待付款但内部状态不是closed的记录: #{exceptions.count}"

if exceptions.count > 0
  puts "  异常记录详情："
  exceptions.limit(5).each do |r|
    puts "    报销单 #{r.invoice_number}: 内部状态=#{r.status}, 外部状态=#{r.external_status}, 手动覆盖=#{r.manual_override?}"
  end
end

puts "\n5. 验证逻辑一致性："
total_should_be_closed = Reimbursement.where(external_status: paid_statuses, manual_override: false).count
actual_closed = Reimbursement.where(external_status: paid_statuses, status: 'closed').count
puts "  应该为closed的记录数（外部状态为已付款/待付款且无手动覆盖）: #{total_should_be_closed}"
puts "  实际为closed的记录数（外部状态为已付款/待付款）: #{actual_closed}"
puts "  逻辑一致性: #{total_should_be_closed == actual_closed ? '✅ 一致' : '❌ 不一致'}"