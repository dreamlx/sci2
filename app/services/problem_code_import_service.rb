# app/services/problem_code_import_service.rb
require 'csv'

class ProblemCodeImportService
  def initialize(file_path)
    @file_path = file_path
  end

  def import
    result = initialize_result

    begin
      # 强制使用 UTF-8 a编码读取文件，并处理BOM
      content = File.read(@file_path, encoding: 'bom|utf-8')
      Rails.logger.debug '========== [Debug Import] File content read with BOM|UTF-8 encoding. =========='
      Rails.logger.debug "  Content encoding before processing: #{content.encoding.name}"
      Rails.logger.debug "  Content starts with (first 50 chars): #{content[0..49].dump}"

      content.strip!
      # BOM should be removed by 'bom|utf-8', but we can log for verification
      original_length = content.bytesize
      content.sub!("\xEF\xBB\xBF", '')
      new_length = content.bytesize

      Rails.logger.debug "  BOM removal check: #{original_length - new_length} bytes removed."
      Rails.logger.debug "  Content encoding after processing: #{content.encoding.name}"
      Rails.logger.debug "  Content starts with after processing (first 50 chars): #{content[0..49].dump}"

      Rails.logger.debug '========== [Debug Import] Starting CSV parsing... =========='
      CSV.parse(content, headers: true, encoding: 'UTF-8').each.with_index do |row, index|
        Rails.logger.debug "  Processing row #{index + 1}: #{row.to_h.inspect}"

        begin
          result[:current_row] = index + 1
          process_row(row, result)
        rescue StandardError => e
          result[:details][:errors] ||= []
          result[:details][:errors] << {
            row: index + 1,
            error: e.message,
            data: row.to_h
          }
          Rails.logger.error "Row #{index + 1} import failed: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      end
      Rails.logger.debug '========== [Debug Import] CSV parsing finished. =========='
    rescue StandardError => e
      result[:success] = false
      result[:error] = e.message
      Rails.logger.error "Import failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    ensure
      result[:current_row] = nil
    end

    result
  end

  private

  def initialize_result
    { success: true, error: nil, current_row: nil, details: { fee_types: [], problem_types: [], errors: [] } }
  end

  def process_row(row, result)
    # 清理数据
    fee_type_params = {
      reimbursement_type_code: clean_text_field(row['reimbursement_type_code']),
      meeting_type_code: format_code_value(row['meeting_type_code']),
      expense_type_code: format_code_value(row['expense_type_code']),
      name: clean_text_field(row['expense_type_name']),
      meeting_name: clean_text_field(row['meeting_type_name'])
    }

    problem_type_params = {
      issue_code: format_code_value(row['issue_code']),
      title: clean_text_field(row['problem_title']),
      sop_description: clean_text_field(row['sop_description']),
      standard_handling: clean_text_field(row['standard_handling']),
      legacy_problem_code: clean_text_field(row['legacy_problem_code'])
    }

    # 验证数据
    fee_type_errors = validate_fee_type_params(fee_type_params)
    problem_type_errors = validate_problem_type_params(problem_type_params)

    if fee_type_errors.any? || problem_type_errors.any?
      result[:details][:errors] ||= []
      result[:details][:errors] << {
        row: result[:current_row] || 0,
        errors: fee_type_errors + problem_type_errors,
        data: row.to_h
      }
      return
    end

    # Skip if essential data is missing
    return if fee_type_params.values_at(:reimbursement_type_code, :meeting_type_code, :expense_type_code).any?(&:blank?)
    return if problem_type_params.values.any?(&:blank?)

    # Process FeeType
    fee_type, fee_type_action = process_fee_type(fee_type_params)
    fee_type_data = fee_type.as_json
    # 确保返回的数据结构符合导入结果页面的期望
    fee_type_data['code'] = fee_type_data['expense_type_code']
    fee_type_data['title'] = fee_type_data['name']
    update_result_with_action(result, :fee_types, fee_type_action, fee_type_data)

    # Process ProblemType
    problem_type, problem_type_action = process_problem_type(problem_type_params, fee_type)
    problem_type_data = problem_type.as_json
    # 确保返回的数据结构符合导入结果页面的期望
    problem_type_data['code'] = problem_type_data['issue_code']
    problem_type_data['fee_type'] = fee_type.display_name
    update_result_with_action(result, :problem_types, problem_type_action, problem_type_data)
  end

  def process_fee_type(params)
    fee_type = FeeType.find_or_initialize_by(
      reimbursement_type_code: params[:reimbursement_type_code],
      meeting_type_code: params[:meeting_type_code],
      expense_type_code: params[:expense_type_code]
    )

    action = fee_type.new_record? ? :imported : :updated

    fee_type.assign_attributes(
      name: params[:name],
      meeting_name: params[:meeting_name],
      active: true
    )

    fee_type.save! if fee_type.changed?

    [fee_type, action]
  end

  def process_problem_type(params, fee_type)
    problem_type = ProblemType.find_or_initialize_by(
      fee_type_id: fee_type.id,
      issue_code: params[:issue_code]
    )

    action = problem_type.new_record? ? :imported : :updated

    problem_type.assign_attributes(
      title: params[:title],
      sop_description: params[:sop_description],
      standard_handling: params[:standard_handling],
      active: true
    )

    # 修复：如果CSV中提供了legacy_problem_code，使用CSV中的值
    if params[:legacy_problem_code].present?
      problem_type.legacy_problem_code = params[:legacy_problem_code]
    else
      # 否则使用虚拟字段计算
      problem_type.legacy_problem_code
    end

    problem_type.save! if problem_type.changed?

    [problem_type, action]
  end

  def update_result_with_action(result, type, action, details)
    return unless action

    details['action'] = action
    result[:details][type] << details
  end

  def format_code_value(value, target_length = 2)
    return nil if value.nil? || value.to_s.strip.empty?

    # 转换为字符串并去除前后空格
    code_str = value.to_s.strip

    # 如果已经是目标长度的数字格式，直接返回
    return code_str if code_str.match?(/^\d{#{target_length}}$/)

    # 如果是数字且长度不足，前面补0
    return code_str.rjust(target_length, '0') if code_str.match?(/^\d+$/)

    # 如果是 "00"（通用类型），直接返回
    return code_str if code_str == '00'

    # 其他情况，原样返回（包括非数字格式）
    code_str
  end

  def validate_fee_type_params(params)
    errors = []

    # 验证reimbursement_type_code
    unless %w[EN MN].include?(params[:reimbursement_type_code])
      errors << "Invalid reimbursement_type_code: #{params[:reimbursement_type_code]}"
    end

    # 验证meeting_type_code格式
    unless params[:meeting_type_code].match?(/^\d{2}$/)
      errors << "Invalid meeting_type_code: #{params[:meeting_type_code]}"
    end

    # 验证expense_type_code格式
    unless params[:expense_type_code].match?(/^\d{2}$/)
      errors << "Invalid expense_type_code: #{params[:expense_type_code]}"
    end

    errors
  end

  def validate_problem_type_params(params)
    errors = []

    # 验证issue_code格式
    errors << "Invalid issue_code: #{params[:issue_code]}" unless params[:issue_code].match?(/^\d+$/)

    # 验证字段长度
    errors << 'SOP description too long (max 2000 characters)' if params[:sop_description]&.length&.> 2000

    errors << 'Standard handling too long (max 1000 characters)' if params[:standard_handling]&.length&.> 1000

    errors
  end

  def clean_text_field(value)
    return nil if value.nil?

    # 移除BOM和特殊字符
    cleaned = value.to_s.strip
    cleaned = cleaned.gsub("\xEF\xBB\xBF", '') # BOM
    cleaned = cleaned.gsub('"', '"') # 中文引号替换
    cleaned = cleaned.gsub('\'', "'") # 中文单引号替换
    cleaned = cleaned.gsub(/【/, '[') # 中文括号替换
    cleaned.gsub(/】/, ']') # 中文括号替换
  end
end
