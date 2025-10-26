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

  def create_or_update_express_receipt(reimbursement, tracking_number, row_data, row_number)
    # 查找或创建快递收单工单
    filling_id = extract_field_value(row_data, :filling_id)
    work_order = if filling_id.present?
                  ExpressReceiptWorkOrder.find_or_initialize_by(filling_id: filling_id)
                else
                  ExpressReceiptWorkOrder.new
                end

    # 设置字段值
    work_order.assign_attributes(
      reimbursement: reimbursement,
      tracking_number: tracking_number,
      operation_notes: extract_field_value(row_data, :operation_notes),
      received_at: parse_date_field(extract_field_value(row_data, :received_at)),
      filling_id: filling_id,
      status: 'pending',
      creator: @current_admin_user,
      data_source: row_data.to_json
    )

    unless work_order.save
      @errors << "第#{row_number}行: 保存快递收单工单失败 - #{work_order.errors.full_messages.join(', ')}"
      @error_count += 1
      return false
    end

    true
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