# 附件相关费用类型种子数据
puts "创建附件相关费用类型..."

# 附件凭证费用类型 - 用于纯凭证附件（金额为0）
attachment_evidence = FeeType.find_or_create_by(code: 'ATTACHMENT_EVIDENCE') do |ft|
  ft.title = '附件凭证'
  ft.name = '附件凭证'
  ft.meeting_type = '通用'
  ft.active = true
end

puts "创建费用类型: #{attachment_evidence.title} (#{attachment_evidence.code})"

# 附件费用类型 - 用于包含实际费用的附件
attachment_expense = FeeType.find_or_create_by(code: 'ATTACHMENT_EXPENSE') do |ft|
  ft.title = '附件费用'
  ft.name = '附件费用'
  ft.meeting_type = '通用'
  ft.active = true
end

puts "创建费用类型: #{attachment_expense.title} (#{attachment_expense.code})"

# 图片凭证费用类型 - 专门用于图片附件
image_evidence = FeeType.find_or_create_by(code: 'IMAGE_EVIDENCE') do |ft|
  ft.title = '图片凭证'
  ft.name = '图片凭证'
  ft.meeting_type = '通用'
  ft.active = true
end

puts "创建费用类型: #{image_evidence.title} (#{image_evidence.code})"

# 文档凭证费用类型 - 专门用于文档附件
document_evidence = FeeType.find_or_create_by(code: 'DOCUMENT_EVIDENCE') do |ft|
  ft.title = '文档凭证'
  ft.name = '文档凭证'
  ft.meeting_type = '通用'
  ft.active = true
end

puts "创建费用类型: #{document_evidence.title} (#{document_evidence.code})"

puts "附件相关费用类型创建完成！"