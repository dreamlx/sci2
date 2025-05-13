# app/services/operation_history_import_service.rb
class OperationHistoryImportService
  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @imported_count = 0
    @skipped_count = 0 # 用于重复记录
    @updated_reimbursement_count = 0
    @error_count = 0
    @errors = []
    @unmatched_histories = []
    Current.admin_user = current_admin_user # 设置 Current.admin_user 用于回调
  end
  
  def import(test_spreadsheet = nil)
    return { success: false, errors: ["文件不存在"] } unless @file.present?
    
    begin
      file_path = @file.respond_to?(:tempfile) ? @file.tempfile.to_path.to_s : @file.path
      extension = File.extname(file_path).delete('.').downcase.to_sym
      spreadsheet = test_spreadsheet || Roo::Spreadsheet.open(file_path, extension: extension)
      # Handle both Excel and CSV files
      sheet = if spreadsheet.respond_to?(:sheet)
                spreadsheet.sheet(0)
              else
                spreadsheet # Directly use spreadsheet if it's a CSV
              end
      
      headers = sheet.row(1).map { |h| h.to_s.strip }
      sheet.each_with_index do |row, idx|
        next if idx == 0
        
        row_data = Hash[headers.zip(row)]
        import_operation_history(row_data, idx + 1)
      end
      
      {
        success: true,
        imported: @imported_count,
        skipped: @skipped_count,
        updated_reimbursements: @updated_reimbursement_count,
        unmatched: @unmatched_histories.count,
        errors: @error_count,
        error_details: @errors,
        unmatched_histories: @unmatched_histories
      }
    rescue => e
      Rails.logger.error "Operation History Import Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, errors: ["导入过程中发生错误: #{e.message}"] }
    end
  end
  
  private
  
  def import_operation_history(row, row_number)
    document_number = row['单据编号']&.strip
    operation_type = row['操作类型']&.strip
    operation_time_str = row['操作日期']
    operator = row['操作人']&.strip
    notes = row['操作意见']&.strip

    Rails.logger.info "Importing history for row #{row_number}: Doc: #{document_number}, Type: #{operation_type}, Time Str: #{operation_time_str}, Operator: #{operator}, Notes: #{notes}"

    unless document_number.present? && operation_type.present? && operation_time_str.present? && operator.present?
      @error_count += 1
      @errors << "行 #{row_number}: 缺少必要字段 (单据编号, 操作类型, 操作日期, 操作人)"
      Rails.logger.warn "Skipping row #{row_number} due to missing required fields."
      return
    end

    # 查找报销单
    reimbursement = Reimbursement.find_by(invoice_number: document_number)

    unless reimbursement
      @unmatched_histories << { row: row_number, document_number: document_number, error: "报销单不存在" }
      Rails.logger.warn "Skipping row #{row_number}: Reimbursement #{document_number} not found."
      return
    end

    operation_time = parse_datetime(operation_time_str)
    Rails.logger.info "Parsed operation_time: #{operation_time}"

    # 重复检查 (Req 14)
    if operation_time
      Rails.logger.info "Checking for duplicates for Doc: #{document_number}, Type: #{operation_type}, Operator: #{operator}"
      # Query for potential duplicates based on other attributes
      potential_duplicates = OperationHistory.where(
        document_number: document_number,
        operation_type: operation_type,
        operator: operator
      )
      Rails.logger.info "Found #{potential_duplicates.count} potential duplicates."

      # Check if any potential duplicate has an operation_time within a small time window
      is_duplicate = potential_duplicates.any? do |existing_history|
        existing_history.operation_time.present? &&
        (existing_history.operation_time - operation_time).abs <= 5.seconds # 5秒容差
      end

      if is_duplicate
        @skipped_count += 1
        return # 跳过重复记录
      end
    end
    
    # 创建操作历史
    operation_history = OperationHistory.new(
      document_number: document_number,
      operation_type: operation_type,
      operation_time: operation_time,
      operator: operator,
      notes: notes,
      form_type: row['表单类型'],
      operation_node: row['操作节点']
    )
    
    if operation_history.save
      @imported_count += 1
    else
      @error_count += 1
      @errors << "行 #{row_number} (单号: #{document_number}): #{operation_history.errors.full_messages.join(', ')}"
      Rails.logger.error "Failed to save operation history for row #{row_number}: #{operation_history.errors.full_messages.join(', ')}"
    end
  end
  
  def parse_datetime(datetime_string)
    return nil unless datetime_string.present?
    begin
      datetime_string.is_a?(Date) || datetime_string.is_a?(DateTime) ? datetime_string : DateTime.parse(datetime_string.to_s).in_time_zone
    rescue ArgumentError
      nil
    end
  end
end