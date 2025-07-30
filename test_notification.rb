# 创建测试报销单
puts "创建测试报销单..."
reimbursement = Reimbursement.create!(
  invoice_number: "TEST#{Time.now.to_i}",
  document_name: "测试报销单",
  applicant: "测试用户",
  applicant_id: "TEST001",
  company: "测试公司",
  department: "测试部门",
  amount: 500.00,
  receipt_status: "pending",
  status: "pending",
  is_electronic: false
)
puts "报销单ID: #{reimbursement.id}, 发票号: #{reimbursement.invoice_number}"

# 标记所有记录为已查看
puts "\n标记所有记录为已查看..."
reimbursement.mark_all_as_viewed!
reimbursement.reload
puts "has_unviewed_express_receipts?: #{reimbursement.has_unviewed_express_receipts?}"
puts "last_viewed_express_receipts_at: #{reimbursement.last_viewed_express_receipts_at}"

# 设置Current.admin_user
puts "\n设置Current.admin_user..."
admin_user = AdminUser.first
Current.admin_user = admin_user
puts "Current.admin_user: #{Current.admin_user.email}"

# 导入快递收单
puts "\n导入快递收单..."
service = ExpressReceiptImportService.new(nil, admin_user)
service.send(:import_express_receipt, {
  '单号' => reimbursement.invoice_number,
  '操作意见' => '快递单号: SF1001',
  '操作时间' => Time.current.to_s
}, 1)

# 检查通知状态
puts "\n检查通知状态..."
reimbursement.reload
puts "has_unviewed_express_receipts?: #{reimbursement.has_unviewed_express_receipts?}"
puts "last_viewed_express_receipts_at: #{reimbursement.last_viewed_express_receipts_at}"

puts "\n测试完成！"