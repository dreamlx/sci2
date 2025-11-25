# app/services/unified_express_receipt_import_service.rb
# 统一的快递收单导入服务 - 替代原有的两个重复服务
class UnifiedExpressReceiptImportService < BaseImportService
  TRACKING_NUMBER_REGEX = /快递单号[：:]\s*(\w+)/i

  # 字段映射配置 - 支持多种字段名变体
  FIELD_MAPPINGS = {
    document_number: %w[单据编号 单号 报销单号],
    operation_notes: %w[操作意见 备注 说明],
    received_at: %w[操作时间 操作日期 收单时间 收单日期],
    filling_id: ['Filling ID', '填充ID', '记录ID']
  }.freeze

  def import(test_spreadsheet = nil)
    # 使用基类的通用文件验证和解析
    parse_result = parse_file(test_spreadsheet)
    return parse_result unless parse_result[:success]

    sheet = parse_result[:sheet]
    headers = parse_result[:headers]

    # 预验证：检查必需字段
    validation_result = validate_required_fields(headers)
    return validation_result unless validation_result[:success]

    # 处理每一行数据
    process_rows(sheet, headers) do |row_data, row_number|
      import_express_receipt(row_data, row_number)
    end

    format_result(
      unmatched_receipts: @unmatched_receipts,
      field_mapping_issues: @field_mapping_issues || []
    )
  end

  private

  def validate_required_fields(headers)
    required_fields = %w[快递单号]
    missing_fields = required_fields.select { |field| !headers.include?(field) }

    if missing_fields.any?
      {
        success: false,
        errors: ["缺少必需字段: #{missing_fields.join(', ')}。请确保文件包含以下列: #{required_fields.join(', ')}"]
      }
    else
      { success: true }
    end
  end

  def import_express_receipt(row_data, row_number)
    begin
      # 1. 提取快递单号和单据编号
      document_number = extract_field_value(row_data, :document_number)
      tracking_number = extract_receipt_number(row_data, row_number)
      return if document_number.nil? || tracking_number.nil?

      # 2. 查找报销单
      reimbursement = find_reimbursement(document_number)

      if reimbursement
        # 3. 重复记录检查
        if check_duplicate_record(reimbursement, tracking_number)
          @skipped_count += 1
          Rails.logger.info "跳过重复记录: 报销单#{document_number}, 快递单号#{tracking_number}"
          return
        end

        if create_or_update_express_receipt(reimbursement, tracking_number, row_data, row_number)
          @created_count += 1
        end
      else
        handle_unmatched_receipt(tracking_number, row_data, row_number)
        @skipped_count += 1
      end

    rescue => e
      handle_error(e, message: "处理第#{row_number}行数据时出错", reraise: false)
    end
  end

  def extract_receipt_number(row_data, row_number)
    # 尝试直接从快递单号字段获取
    receipt_number = row_data['快递单号']&.to_s&.strip

    if receipt_number.blank?
      # 尝试从其他可能包含快递单号的字段中提取
      row_data.each do |field_name, field_value|
        next if field_value.blank?

        match = field_value.to_s.match(TRACKING_NUMBER_REGEX)
        if match
          receipt_number = match[1]
          Rails.logger.info "从字段 '#{field_name}' 提取到快递单号: #{receipt_number}"
          break
        end
      end
    end

    if receipt_number.blank?
      @errors << "第#{row_number}行: 无法找到有效的快递单号"
      return nil
    end

    receipt_number
  end

  def find_reimbursement(document_number)
    Reimbursement.find_by(invoice_number: document_number)
  end

  def extract_field_value(row_data, field_type)
    field_names = FIELD_MAPPINGS[field_type] || []
    field_names.each do |field_name|
      value = row_data[field_name]&.to_s&.strip
      return value if value.present?
    end
    nil
  end

  def check_duplicate_record(reimbursement, tracking_number)
    ExpressReceiptWorkOrder.exists?(reimbursement_id: reimbursement.id, tracking_number: tracking_number)
  end

  def create_or_update_express_receipt(reimbursement, tracking_number, row_data, row_number)
    # 查找或创建快递收单工单
    filling_id = extract_field_value(row_data, :filling_id)
    work_order = if filling_id.present?
                  ExpressReceiptWorkOrder.find_or_initialize_by(filling_id: filling_id)
                else
                  ExpressReceiptWorkOrder.new
                end

    received_at = parse_date_field_enhanced(extract_field_value(row_data, :received_at), row_number)

    # 使用事务保护数据一致性
    ActiveRecord::Base.transaction do
      # 设置字段值 - 修复字段映射错误，与原版保持一致
      work_order.assign_attributes(
        reimbursement: reimbursement,
        tracking_number: tracking_number,
        received_at: received_at,
        filling_id: filling_id,
        status: 'completed', # 与原版保持一致
        created_by: @current_admin_user.id # 修复字段名错误
      )

      unless work_order.save
        @errors << "第#{row_number}行: 保存快递收单工单失败 - #{work_order.errors.full_messages.join(', ')}"
        @error_count += 1
        return false
      end

      # 更新报销单状态和通知重置
      update_reimbursement_status(reimbursement, received_at)
      
      true
    end
  rescue StateMachines::InvalidTransition => e
    @errors << "第#{row_number}行: 更新报销单状态失败 - #{e.message}"
    @error_count += 1
    false
  rescue StandardError => e
    @errors << "第#{row_number}行: 事务处理失败 - #{e.message}"
    @error_count += 1
    false
  end

  def update_reimbursement_status(reimbursement, received_at)
    # 更新报销单收单状态
    reimbursement.mark_as_received(received_at) if received_at

    # 重置通知状态
    if reimbursement.last_viewed_express_receipts_at.present?
      reimbursement.update_column(:last_viewed_express_receipts_at, nil)
      Rails.logger.debug "重置报销单 ##{reimbursement.id} 的通知状态"
    end
  end

  def parse_date_field(date_string)
    return nil if date_string.blank?

    begin
      # 尝试多种日期格式
      Date.parse(date_string) ||
      Time.parse(date_string) ||
      DateTime.parse(date_string)
    rescue ArgumentError
      Rails.logger.warn "无法解析日期格式: #{date_string}"
      nil
    end
  end

  def parse_date_field_enhanced(date_string, row_number = nil)
    return nil if date_string.blank?

    # 如果已经是时间对象，直接返回
    if date_string.is_a?(Date) || date_string.is_a?(DateTime) || date_string.is_a?(Time)
      return date_string
    end

    date_str = date_string.to_s.strip
    return nil if date_str.blank?

    # 检查Excel序列号格式并拒绝
    if date_str.match?(/^\d+(\.\d+)?$/)
      Rails.logger.warn "拒绝Excel序列号格式的时间字符串: '#{date_str}'#{row_number ? " (第#{row_number}行)" : ''}"
      return nil
    end

    begin
      # 尝试标准解析
      DateTime.parse(date_str)
    rescue ArgumentError
      # 尝试常见格式
      common_formats = [
        '%Y-%m-%d %H:%M:%S',    # 2025-01-01 10:00:00
        '%Y/%m/%d %H:%M:%S',    # 2025/01/01 10:00:00
        '%Y-%m-%d %H:%M',       # 2025-01-01 10:00
        '%Y/%m/%d %H:%M',       # 2025/01/01 10:00
        '%Y-%m-%d',             # 2025-01-01
        '%Y/%m/%d',             # 2025/01/01
        '%d/%m/%Y %H:%M:%S',    # 01/01/2025 10:00:00
        '%m/%d/%Y %H:%M:%S',    # 01/01/2025 10:00:00
        '%d-%m-%Y %H:%M:%S',    # 01-01-2025 10:00:00
        '%m-%d-%Y %H:%M:%S'     # 01-01-2025 10:00:00
      ]

      common_formats.each do |format|
        parsed_time = DateTime.strptime(date_str, format)
        Rails.logger.debug "成功解析时间 '#{date_str}' 使用格式 '#{format}'#{row_number ? " (第#{row_number}行)" : ''} => #{parsed_time}"
        return parsed_time
      rescue ArgumentError
        # 继续尝试下一种格式
      end

      # 所有格式都尝试失败
      Rails.logger.warn "无法解析时间字符串: '#{date_str}'#{row_number ? " (第#{row_number}行)" : ''}"
      nil
    rescue StandardError => e
      Rails.logger.error "时间解析异常: '#{date_str}'#{row_number ? " (第#{row_number}行)" : ''} - #{e.message}"
      nil
    end
  end

  def handle_unmatched_receipt(receipt_number, row_data, row_number)
    unmatched_info = {
      receipt_number: receipt_number,
      row_number: row_number,
      document_number: extract_field_value(row_data, :document_number),
      row_data: row_data
    }

    @unmatched_receipts << unmatched_info
    Rails.logger.info "未匹配的快递单号: #{receipt_number} (第#{row_number}行)"
  end
end