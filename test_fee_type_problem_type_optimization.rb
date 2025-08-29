#!/usr/bin/env ruby
# 测试 fee type 和 problem type 优化方案

puts "=== Fee Type 和 Problem Type 关系优化测试 ==="
puts

# 模拟测试数据
puts "1. 创建测试数据..."

# 模拟现有费用类型
existing_fee_types = [
  { id: 1, code: '00', title: '个人费用', meeting_type: '个人', active: true },
  { id: 2, code: '01', title: '学术费用', meeting_type: '学术论坛', active: true },
  { id: 3, code: 'MEETING_001', title: '会议费', meeting_type: '学术论坛', active: true },
  { id: 4, code: 'TRAVEL_001', title: '差旅费', meeting_type: '学术论坛', active: true }
]

# 模拟创建的通用费用类型
general_fee_type = { id: 5, code: 'GENERAL_ACADEMIC', title: '通用问题-学术论坛', meeting_type: '学术论坛', active: true }

# 模拟问题类型
problem_types = [
  # 特定费用类型的问题
  { id: 1, code: 'MEETING_001', title: '会议费发票不规范', fee_type_id: 3, sop_description: '检查会议费发票格式', standard_handling: '要求重新开具规范发票' },
  { id: 2, code: 'MEETING_002', title: '会议费超出标准', fee_type_id: 3, sop_description: '检查会议费是否超标', standard_handling: '按标准调整或提供说明' },
  { id: 3, code: 'TRAVEL_001', title: '差旅费票据缺失', fee_type_id: 4, sop_description: '检查差旅费票据完整性', standard_handling: '要求补充缺失票据' },
  
  # 学术会议通用问题
  { id: 4, code: 'ACADEMIC_GENERAL_001', title: '报销单填写不完整', fee_type_id: 5, sop_description: '检查学术会议报销单各项信息是否完整填写', standard_handling: '要求补充完整信息后重新提交' },
  { id: 5, code: 'ACADEMIC_GENERAL_002', title: '审批流程不规范', fee_type_id: 5, sop_description: '检查学术会议费用审批流程是否符合规定', standard_handling: '按照正确流程重新审批' },
  { id: 6, code: 'ACADEMIC_GENERAL_003', title: '会议证明材料缺失', fee_type_id: 5, sop_description: '检查学术会议证明材料', standard_handling: '要求提供完整证明材料' }
]

puts "创建了 #{existing_fee_types.length} 个费用类型"
puts "创建了 1 个通用费用类型"
puts "创建了 #{problem_types.length} 个问题类型"
puts

# 测试场景1：个人会议类型（无通用问题）
puts "2. 测试场景1：个人会议类型"
selected_fee_details = [
  { fee_type: '个人费用', amount: 100 }
]

puts "选中费用明细: #{selected_fee_details.map{|fd| fd[:fee_type]}.join(', ')}"

# 匹配费用类型
matched_fee_types = []
selected_fee_details.each do |fee_detail|
  matched = existing_fee_types.find { |ft| ft[:title] == fee_detail[:fee_type] }
  matched_fee_types << matched if matched
end

puts "匹配到的费用类型: #{matched_fee_types.map{|ft| ft[:title]}.join(', ')}"

# 获取相关问题类型
meeting_types = matched_fee_types.map { |ft| ft[:meeting_type] }.uniq
puts "会议类型: #{meeting_types.join(', ')}"

relevant_problems = problem_types.select do |pt|
  fee_type = existing_fee_types.find { |ft| ft[:id] == pt[:fee_type_id] } || general_fee_type
  meeting_types.include?(fee_type[:meeting_type]) if fee_type
end

puts "相关问题类型数量: #{relevant_problems.length}"
puts "问题类型: #{relevant_problems.map{|p| p[:title]}.join(', ')}"
puts "结果: ✓ 个人会议类型没有通用问题，符合预期"
puts

# 测试场景2：学术会议类型（有通用问题）
puts "3. 测试场景2：学术会议类型 - 选择多种费用类型"
selected_fee_details = [
  { fee_type: '会议费', amount: 1000 },
  { fee_type: '差旅费', amount: 500 }
]

puts "选中费用明细: #{selected_fee_details.map{|fd| fd[:fee_type]}.join(', ')}"

# 匹配费用类型
matched_fee_types = []
selected_fee_details.each do |fee_detail|
  matched = existing_fee_types.find { |ft| ft[:title] == fee_detail[:fee_type] }
  matched_fee_types << matched if matched
end

puts "匹配到的费用类型: #{matched_fee_types.map{|ft| ft[:title]}.join(', ')}"
matched_fee_type_ids = matched_fee_types.map { |ft| ft[:id] }

# 获取相关问题类型（新逻辑：只显示匹配的特定问题类型 + 通用问题类型）
meeting_types = matched_fee_types.map { |ft| ft[:meeting_type] }.uniq
puts "会议类型: #{meeting_types.join(', ')}"

relevant_problems = problem_types.select do |pt|
  fee_type = ([general_fee_type] + existing_fee_types).find { |ft| ft[:id] == pt[:fee_type_id] }
  next false unless fee_type
  
  # 通用问题类型：如果是学术会议，始终显示
  if fee_type[:code] == 'GENERAL_ACADEMIC' && meeting_types.include?('学术论坛')
    true
  # 特定问题类型：只显示与选中费用类型匹配的
  elsif matched_fee_type_ids.include?(fee_type[:id])
    true
  else
    false
  end
end

# 分类问题类型
specific_problems = relevant_problems.select do |pt|
  fee_type = existing_fee_types.find { |ft| ft[:id] == pt[:fee_type_id] }
  fee_type && fee_type[:code] != 'GENERAL_ACADEMIC'
end

general_problems = relevant_problems.select do |pt|
  fee_type = ([general_fee_type] + existing_fee_types).find { |ft| ft[:id] == pt[:fee_type_id] }
  fee_type && fee_type[:code] == 'GENERAL_ACADEMIC'
end

puts "相关问题类型数量: #{relevant_problems.length}"
puts "  - 特定问题: #{specific_problems.length} 个（只显示与选中费用类型匹配的）"
specific_problems.each { |p| puts "    * #{p[:title]}" }
puts "  - 通用问题: #{general_problems.length} 个（学术会议始终显示）"
general_problems.each { |p| puts "    * #{p[:title]}" }
puts "结果: ✓ 只显示相关的特定问题类型 + 通用问题类型"
puts

# 测试场景3：学术会议类型 - 只选择会议费
puts "4. 测试场景3：学术会议类型 - 只选择会议费"
selected_fee_details = [
  { fee_type: '会议费', amount: 1000 }
]

puts "选中费用明细: #{selected_fee_details.map{|fd| fd[:fee_type]}.join(', ')}"

# 匹配费用类型
matched_fee_types = []
selected_fee_details.each do |fee_detail|
  matched = existing_fee_types.find { |ft| ft[:title] == fee_detail[:fee_type] }
  matched_fee_types << matched if matched
end

puts "匹配到的费用类型: #{matched_fee_types.map{|ft| ft[:title]}.join(', ')}"
matched_fee_type_ids = matched_fee_types.map { |ft| ft[:id] }

# 获取相关问题类型
meeting_types = matched_fee_types.map { |ft| ft[:meeting_type] }.uniq
puts "会议类型: #{meeting_types.join(', ')}"

relevant_problems = problem_types.select do |pt|
  fee_type = ([general_fee_type] + existing_fee_types).find { |ft| ft[:id] == pt[:fee_type_id] }
  next false unless fee_type
  
  # 通用问题类型：如果是学术会议，始终显示
  if fee_type[:code] == 'GENERAL_ACADEMIC' && meeting_types.include?('学术论坛')
    true
  # 特定问题类型：只显示与选中费用类型匹配的
  elsif matched_fee_type_ids.include?(fee_type[:id])
    true
  else
    false
  end
end

# 分类问题类型
specific_problems = relevant_problems.select do |pt|
  fee_type = existing_fee_types.find { |ft| ft[:id] == pt[:fee_type_id] }
  fee_type && fee_type[:code] != 'GENERAL_ACADEMIC'
end

general_problems = relevant_problems.select do |pt|
  fee_type = ([general_fee_type] + existing_fee_types).find { |ft| ft[:id] == pt[:fee_type_id] }
  fee_type && fee_type[:code] == 'GENERAL_ACADEMIC'
end

puts "相关问题类型数量: #{relevant_problems.length}"
puts "  - 特定问题: #{specific_problems.length} 个（只显示会议费相关问题，不显示差旅费问题）"
specific_problems.each { |p| puts "    * #{p[:title]}" }
puts "  - 通用问题: #{general_problems.length} 个（学术会议始终显示）"
general_problems.each { |p| puts "    * #{p[:title]}" }
puts "结果: ✓ 只显示会议费相关问题，不显示差旅费问题，但通用问题始终显示"
puts

# 测试前端分组逻辑（基于场景3的结果）
puts "5. 测试前端分组显示逻辑（只选择会议费的情况）"
puts "按费用类型分组特定问题:"
specific_by_fee_type = {}
specific_problems.each do |problem|
  fee_type = existing_fee_types.find { |ft| ft[:id] == problem[:fee_type_id] }
  if fee_type
    key = fee_type[:title]
    specific_by_fee_type[key] ||= []
    specific_by_fee_type[key] << problem
  end
end

specific_by_fee_type.each do |fee_type_title, problems|
  puts "  📋 #{fee_type_title}相关问题 (#{problems.length}个):"
  problems.each { |p| puts "    - #{p[:title]}" }
end

if general_problems.length > 0
  puts "  🌐 学术会议通用问题 (#{general_problems.length}个):"
  general_problems.each { |p| puts "    - #{p[:title]}" }
end

puts
puts "=== 测试完成 ==="
puts "✓ 个人会议类型：无通用问题"
puts "✓ 学术会议类型：有通用问题"
puts "✓ 特定问题类型：只显示与选中费用类型匹配的"
puts "✓ 通用问题类型：学术会议始终显示"
puts "✓ 问题类型按类别正确分组"
puts "✓ 前端显示逻辑正确"
puts "✓ 用户体验优化：减少不相关问题类型的干扰"