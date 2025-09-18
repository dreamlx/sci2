#!/usr/bin/env ruby

# 调试快递收单导入问题的脚本
require_relative 'config/environment'

# 模拟Excel数据的一行
sample_row_data = {
  '序号' => '1',
  '单据类型' => '个人日常和差旅（含小沟会）报销单',
  '单号' => 'ER24449549',
  '申请人' => '林翔宇',
  '操作日期' => '2025-09-12 10:06:32',  # 注意：这里是操作日期，不是操作时间
  '操作类型' => '单据接收',
  '操作意见' => '快递单号：SF0288143663223'
}

puts "=== 快递收单导入问题诊断 ==="
puts

# 1. 检查字段映射
puts "1. 字段映射检查："
puts "   Excel字段: #{sample_row_data.keys.inspect}"

expected_fields = ['单据编号', '单号', '操作意见', '操作时间', 'Filling ID']
puts "   系统期望: #{expected_fields.inspect}"

# 2. 模拟导入服务的字段提取逻辑
puts "\n2. 字段提取测试："
document_number = sample_row_data['单据编号']&.strip || sample_row_data['单号']&.strip
operation_notes = sample_row_data['操作意见']&.strip
received_at_str = sample_row_data['操作时间']  # 这里会是nil，因为Excel用的是'操作日期'
filling_id = sample_row_data['Filling ID']&.strip

puts "   单据编号: #{document_number.inspect}"
puts "   操作意见: #{operation_notes.inspect}"
puts "   操作时间: #{received_at_str.inspect} ❌ (nil - 字段名不匹配)"
puts "   Filling ID: #{filling_id.inspect}"

# 3. 快递单号提取测试
TRACKING_NUMBER_REGEX = /快递单号[：:]\s*(\w+)/i
tracking_number = operation_notes&.match(TRACKING_NUMBER_REGEX)&.captures&.first&.strip
puts "\n3. 快递单号提取测试："
puts "   正则表达式: #{TRACKING_NUMBER_REGEX.inspect}"
puts "   提取结果: #{tracking_number.inspect}"

# 4. 报销单查找测试
puts "\n4. 报销单查找测试："
reimbursement = Reimbursement.find_by(invoice_number: document_number)
puts "   查找报销单 #{document_number}: #{reimbursement ? '找到' : '未找到'}"

# 5. 时间解析测试（使用正确的字段名）
puts "\n5. 时间解析测试："
correct_time_str = sample_row_data['操作日期']  # 使用Excel实际的字段名
puts "   Excel时间字段值: #{correct_time_str.inspect}"

# 模拟时间解析函数
def parse_datetime_test(datetime_string)
  return nil unless datetime_string.present?
  
  if datetime_string.is_a?(Date) || datetime_string.is_a?(DateTime) || datetime_string.is_a?(Time)
    return datetime_string
  end
  
  datetime_str = datetime_string.to_s.strip
  return nil if datetime_str.blank?
  
  if datetime_str.match?(/^\d+(\.\d+)?$/)
    puts "   拒绝Excel序列号格式: '#{datetime_str}'"
    return nil
  end
  
  begin
    result = DateTime.parse(datetime_str)
    puts "   标准解析成功: #{result}"
    return result
  rescue ArgumentError
    puts "   标准解析失败，尝试常见格式..."
    common_formats = [
      '%Y-%m-%d %H:%M:%S',
      '%Y/%m/%d %H:%M:%S',
      '%Y-%m-%d %H:%M',
      '%Y/%m/%d %H:%M',
      '%Y-%m-%d',
      '%Y/%m/%d'
    ]
    
    common_formats.each do |format|
      begin
        result = DateTime.strptime(datetime_str, format)
        puts "   使用格式 '#{format}' 解析成功: #{result}"
        return result
      rescue ArgumentError
        # 继续尝试
      end
    end
    
    puts "   所有格式解析失败"
    return nil
  end
end

parsed_time = parse_datetime_test(correct_time_str)

# 6. 问题总结
puts "\n=== 问题诊断结果 ==="
puts "❌ 主要问题：字段名不匹配"
puts "   - Excel使用 '操作日期'，系统期望 '操作时间'"
puts "   - 导致 received_at_str 为 nil"
puts "   - 触发错误：'操作时间不能为空'"
puts
puts "✅ 其他检查正常："
puts "   - 单号提取: #{document_number ? '正常' : '失败'}"
puts "   - 快递单号提取: #{tracking_number ? '正常' : '失败'}"
puts "   - 时间格式: #{parsed_time ? '可解析' : '无法解析'}"
puts "   - 报销单查找: #{reimbursement ? '找到' : '需要检查数据库'}"

puts "\n=== 修复建议 ==="
puts "1. 立即修复：修改导入服务支持 '操作日期' 字段"
puts "2. 长期方案：统一字段命名规范"
puts "3. 用户指导：提供标准的Excel模板"