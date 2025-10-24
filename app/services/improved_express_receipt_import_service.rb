# app/services/improved_express_receipt_import_service.rb
# 改进版快递收单导入服务，支持更好的错误提示和字段兼容性
class ImprovedExpressReceiptImportService
  TRACKING_NUMBER_REGEX = /快递单号[：:]\s*(\w+)/i

  # 字段映射配置 - 支持多种字段名
  FIELD_MAPPINGS = {
    document_number: %w[单据编号 单号 报销单号],
    operation_notes: %w[操作意见 备注 说明],
    received_at: %w[操作时间 操作日期 收单时间 收单日期],
    filling_id: ['Filling ID', '填充ID', '记录ID']
  }.freeze

  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @created_count = 0
    @skipped_count = 0
    @error_count = 0
    @errors = []
    @unmatched_receipts = []
    @field_mapping_issues = []
    Current.admin_user = current_admin_user
  end

  def import(test_spreadsheet = nil)
    return { success: false, errors: ['文件不存在'] } unless @file.present?
    return { success: false, errors: ['导入用户不存在'] } unless @current_admin_user

    begin
      file_path = if @file.respond_to?(:tempfile)
                    @file.tempfile.to_path.to_s
                  else
                    @file.path
                  end

      extension = File.extname(file_path).downcase[1..-1]
      return { success: false, errors: ['不支持的文件格式，请上传 CSV 或 Excel 文件'] } unless %w[csv xls xlsx].include?(extension)

      spreadsheet = test_spreadsheet || Roo::Spreadsheet.open(file_path, extension: extension.to_sym)
      sheet = if spreadsheet.respond_to?(:sheet)
                spreadsheet.sheet(0)
              else
                spreadsheet
              end

      headers = sheet.row(1).map { |h| h.to_s.strip }
      Rails.logger.info "导入文件头部字段: #{headers.inspect}"

      # 预验证：检查必需字段是否存在
      validation_result = validate_headers(headers)
      if validation_result[:has_errors]
        return {
          success: false,
          errors: validation_result[:errors],
          suggestions: validation_result[:suggestions]
        }
      end

      # 建立字段映射
      field_map = build_field_mapping(headers)
      Rails.logger.info "字段映射结果: #{field_map.inspect}"

      # 处理数据行
      sheet.each_with_index do |row, idx|
        next if idx == 0

        row_data = Hash[headers.zip(row)]
        Rails.logger.debug "处理第 #{idx + 1} 行: #{row_data.inspect}"
        import_express_receipt_with_mapping(row_data, idx + 1, field_map)
      end

      # 生成详细的结果报告
      generate_import_result
    rescue StandardError => e
      Rails.logger.error "快递收单导入失败: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, errors: ["导入过程中发生错误: #{e.message}"] }
    end
  end

  private

  def validate_headers(headers)
    errors = []
    suggestions = []
    missing_fields = []

    FIELD_MAPPINGS.each do |field_key, possible_names|
      found = possible_names.any? { |name| headers.include?(name) }
      next if found

      missing_fields << {
        field: field_key,
        expected: possible_names,
        available: headers.select { |h| similar_field?(h, possible_names) }
      }
    end

    if missing_fields.any?
      missing_fields.each do |field_info|
        field_name = field_info[:field]
        expected = field_info[:expected]
        available = field_info[:available]

        error_msg = "缺少必需字段 '#{field_name}'，期望字段名: #{expected.join(' 或 ')}"
        if available.any?
          error_msg += "，发现相似字段: #{available.join(', ')}"
          suggestions << "建议将 '#{available.first}' 重命名为 '#{expected.first}'"
        end
        errors << error_msg
      end

      # 添加通用建议
      suggestions << '请确保Excel文件包含以下必需字段：'
      FIELD_MAPPINGS.each do |field_key, possible_names|
        suggestions << "  - #{field_key}: #{possible_names.join(' 或 ')}"
      end
    end

    {
      has_errors: errors.any?,
      errors: errors,
      suggestions: suggestions
    }
  end

  def build_field_mapping(headers)
    mapping = {}

    FIELD_MAPPINGS.each do |field_key, possible_names|
      found_field = possible_names.find { |name| headers.include?(name) }
      mapping[field_key] = found_field if found_field
    end

    mapping
  end

  def similar_field?(header, possible_names)
    possible_names.any? do |name|
      # 检查是否包含关键词
      name_keywords = name.split(/[：:\s]/)
      header_keywords = header.split(/[：:\s]/)

      name_keywords.any? { |keyword| header.include?(keyword) } ||
        header_keywords.any? { |keyword| name.include?(keyword) }
    end
  end

  def extract_field_value(row, field_key, field_map)
    field_name = field_map[field_key]
    return nil unless field_name

    value = row[field_name]
    value.is_a?(String) ? value.strip : value
  end

  def import_express_receipt_with_mapping(row, row_number, field_map)
    # 使用字段映射提取数据
    document_number = extract_field_value(row, :document_number, field_map)
    operation_notes = extract_field_value(row, :operation_notes, field_map)
    received_at_str = extract_field_value(row, :received_at, field_map)
    filling_id = extract_field_value(row, :filling_id, field_map)

    Rails.logger.debug "第 #{row_number} 行字段提取结果 - 单号: #{document_number.inspect}, 操作意见: #{operation_notes.inspect}, 时间: #{received_at_str.inspect}"

    # 验证必需字段
    validation_errors = []

    unless document_number.present?
      available_fields = row.keys.select { |k| k.match?(/单号|编号/) }
      error_msg = '缺少单号字段'
      error_msg += "，发现字段: #{available_fields.join(', ')}" if available_fields.any?
      validation_errors << error_msg
    end

    validation_errors << '缺少操作意见字段' unless operation_notes.present?

    unless received_at_str.present?
      available_time_fields = row.keys.select { |k| k.match?(/时间|日期/) }
      error_msg = "缺少操作时间字段（期望: #{FIELD_MAPPINGS[:received_at].join(' 或 ')}）"
      error_msg += "，发现时间字段: #{available_time_fields.join(', ')}" if available_time_fields.any?
      validation_errors << error_msg
    end

    if validation_errors.any?
      @error_count += 1
      @errors << "第 #{row_number} 行: #{validation_errors.join('; ')}"
      return
    end

    # 提取快递单号
    tracking_number = operation_notes&.match(TRACKING_NUMBER_REGEX)&.captures&.first&.strip
    unless tracking_number.present?
      @error_count += 1
      @errors << "第 #{row_number} 行: 无法从操作意见中提取快递单号，期望格式: '快递单号：XXXXXX'"
      return
    end

    # 查找报销单
    reimbursement = Reimbursement.find_by(invoice_number: document_number)
    unless reimbursement
      @unmatched_receipts << {
        row: row_number,
        document_number: document_number,
        tracking_number: tracking_number,
        error: '报销单不存在'
      }
      return
    end

    # 解析时间
    received_at = parse_datetime_enhanced(received_at_str, row_number)
    return unless received_at # parse_datetime_enhanced 会处理错误记录

    # 处理记录创建或更新
    process_work_order(row_number, document_number, tracking_number, received_at, filling_id, reimbursement)
  end

  def parse_datetime_enhanced(datetime_string, row_number)
    return nil unless datetime_string.present?

    if datetime_string.is_a?(Date) || datetime_string.is_a?(DateTime) || datetime_string.is_a?(Time)
      return datetime_string
    end

    datetime_str = datetime_string.to_s.strip
    return nil if datetime_str.blank?

    # 检查Excel序列号格式
    if datetime_str.match?(/^\d+(\.\d+)?$/)
      @error_count += 1
      @errors << "第 #{row_number} 行: 时间格式错误，请使用标准时间格式而非Excel序列号: '#{datetime_str}'"
      return nil
    end

    begin
      DateTime.parse(datetime_str)
    rescue ArgumentError
      # 尝试常见格式
      common_formats = [
        '%Y-%m-%d %H:%M:%S',
        '%Y/%m/%d %H:%M:%S',
        '%Y-%m-%d %H:%M',
        '%Y/%m/%d %H:%M',
        '%Y-%m-%d',
        '%Y/%m/%d'
      ]

      common_formats.each do |format|
        result = DateTime.strptime(datetime_str, format)
        Rails.logger.debug "第 #{row_number} 行: 使用格式 '#{format}' 成功解析时间: #{result}"
        return result
      rescue ArgumentError
        # 继续尝试下一种格式
      end

      # 所有格式都失败
      @error_count += 1
      @errors << "第 #{row_number} 行: 无法解析时间格式 '#{datetime_str}'，支持格式: #{common_formats.join(', ')}"
      nil
    end
  end

  def process_work_order(row_number, document_number, tracking_number, received_at, filling_id, reimbursement)
    if filling_id.present?
      # 更新现有记录
      work_order = ExpressReceiptWorkOrder.find_by(filling_id: filling_id)
      unless work_order
        @error_count += 1
        @errors << "第 #{row_number} 行: 找不到对应的填充ID记录 (Filling ID: #{filling_id})"
        return
      end

      update_work_order(work_order, row_number, document_number, tracking_number, received_at, reimbursement)
    else
      # 创建新记录
      create_work_order(row_number, document_number, tracking_number, received_at, reimbursement)
    end
  end

  def update_work_order(work_order, row_number, document_number, tracking_number, received_at, reimbursement)
    ActiveRecord::Base.transaction do
      if work_order.update(
        reimbursement: reimbursement,
        tracking_number: tracking_number,
        received_at: received_at,
        created_by: @current_admin_user.id
      )
        @created_count += 1
        reimbursement.mark_as_received(received_at)
        reset_notification_status(reimbursement)
      else
        @error_count += 1
        error_messages = work_order.errors.full_messages.join(', ')
        @errors << "第 #{row_number} 行 (单号: #{document_number}): 更新失败 - #{error_messages}"
        raise ActiveRecord::Rollback
      end
    end
  end

  def create_work_order(row_number, document_number, tracking_number, received_at, reimbursement)
    # 检查重复记录
    if ExpressReceiptWorkOrder.exists?(reimbursement_id: reimbursement.id, tracking_number: tracking_number)
      @skipped_count += 1
      return
    end

    work_order = ExpressReceiptWorkOrder.new(
      reimbursement: reimbursement,
      status: 'completed',
      tracking_number: tracking_number,
      received_at: received_at,
      created_by: @current_admin_user.id
    )

    ActiveRecord::Base.transaction do
      if work_order.save
        @created_count += 1
        reimbursement.mark_as_received(received_at)
        reset_notification_status(reimbursement)
      else
        @error_count += 1
        error_messages = work_order.errors.full_messages.join(', ')
        @errors << "第 #{row_number} 行 (单号: #{document_number}): 创建失败 - #{error_messages}"
        raise ActiveRecord::Rollback
      end
    end
  rescue StateMachines::InvalidTransition => e
    @error_count += 1
    @errors << "第 #{row_number} 行 (单号: #{document_number}): 更新报销单状态失败 - #{e.message}"
  end

  def reset_notification_status(reimbursement)
    return unless reimbursement.last_viewed_express_receipts_at.present?

    reimbursement.update_column(:last_viewed_express_receipts_at, nil)
    Rails.logger.debug "重置报销单 ##{reimbursement.id} 的通知状态"
  end

  def generate_import_result
    # 错误分类统计
    error_categories = categorize_errors

    result = {
      success: true,
      created: @created_count,
      skipped: @skipped_count,
      unmatched: @unmatched_receipts.count,
      errors: @error_count,
      error_details: @errors,
      unmatched_details: @unmatched_receipts,
      error_summary: {
        total_processed: @created_count + @skipped_count + @error_count + @unmatched_receipts.count,
        successful_rate: calculate_success_rate,
        error_categories: error_categories
      }
    }

    # 添加改进建议
    result[:suggestions] = generate_suggestions(error_categories) if @error_count > 0 || @unmatched_receipts.any?

    result
  end

  def categorize_errors
    categories = {
      field_missing: 0,
      time_format: 0,
      tracking_number: 0,
      reimbursement_not_found: 0,
      validation: 0,
      other: 0
    }

    @errors.each do |error|
      case error
      when /缺少.*字段/
        categories[:field_missing] += 1
      when /时间格式|无法解析时间/
        categories[:time_format] += 1
      when /快递单号/
        categories[:tracking_number] += 1
      when /验证失败|创建失败|更新失败/
        categories[:validation] += 1
      else
        categories[:other] += 1
      end
    end

    categories[:reimbursement_not_found] = @unmatched_receipts.count
    categories
  end

  def calculate_success_rate
    total = @created_count + @skipped_count + @error_count + @unmatched_receipts.count
    return 0 if total == 0

    ((@created_count + @skipped_count).to_f / total * 100).round(2)
  end

  def generate_suggestions(error_categories)
    suggestions = []

    if error_categories[:field_missing] > 0
      suggestions << '字段名问题：请确保Excel文件包含正确的字段名称'
      suggestions << '建议字段名：'
      FIELD_MAPPINGS.each do |field, names|
        suggestions << "  - #{field}: #{names.join(' 或 ')}"
      end
    end

    suggestions << "时间格式问题：请使用标准时间格式，如 '2025-01-01 10:00:00'" if error_categories[:time_format] > 0

    suggestions << "快递单号格式问题：请确保操作意见包含 '快递单号：XXXXXX' 格式" if error_categories[:tracking_number] > 0

    suggestions << '报销单匹配问题：请确认Excel中的单号在系统中存在' if error_categories[:reimbursement_not_found] > 0

    suggestions << '如需帮助，请联系系统管理员并提供此错误报告'
    suggestions
  end
end
