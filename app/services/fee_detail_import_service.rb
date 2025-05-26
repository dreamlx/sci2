# app/services/fee_detail_import_service.rb
class FeeDetailImportService
  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @created_count = 0 # Changed from imported_count
    @updated_count = 0 # Added for clarity
    @skipped_due_to_error_count = 0 # Renamed from error_count for clarity on unprocessable rows
    @errors = [] # Stores detailed error messages for rows that couldn't be processed
    @unmatched_reimbursement_count = 0 # Renamed from unmatched_details.count
    @unmatched_reimbursement_details = [] # Renamed from unmatched_details
    Current.admin_user = current_admin_user # 设置 Current.admin_user 用于回调
  end
  
  def import(test_spreadsheet = nil)
    return { success: false, errors: ["文件不存在"] } unless @file.present?
    
    begin
      file_path = @file.respond_to?(:tempfile) ? @file.tempfile.to_path.to_s : @file.path
      extension = File.extname(file_path).delete('.').downcase.to_sym
      spreadsheet = test_spreadsheet || Roo::Spreadsheet.open(file_path, extension: extension)
      sheet = if spreadsheet.respond_to?(:sheet)
                spreadsheet.sheet(0)
              else
                spreadsheet
              end
      
      headers = sheet.row(1).map { |h| h.to_s.strip }
      # Validate essential headers
      expected_headers = ['报销单单号', '费用id', '费用类型', '原始金额', '费用发生日期'] # Add other essential headers if any
      missing_headers = expected_headers - headers
      unless missing_headers.empty?
        return { success: false, errors: ["CSV文件缺少必要的列: #{missing_headers.join(', ')}"] }
      end

      sheet.each_with_index do |row, idx|
        next if idx == 0 # Skip header row
        
        row_data = Hash[headers.zip(row)]
        import_fee_detail(row_data, idx + 1)
      end
      
      {
        success: @errors.empty?,
        created: @created_count,
        updated: @updated_count,
        unmatched_reimbursement: @unmatched_reimbursement_count,
        skipped_errors: @skipped_due_to_error_count,
        error_details: @errors,
        unmatched_reimbursement_details: @unmatched_reimbursement_details
      }
    rescue Roo::FileNotFound => e
      Rails.logger.error "Fee Detail Import Failed: File not found - #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, errors: ["导入文件未找到: #{e.message}"] }
    rescue CSV::MalformedCSVError => e
      Rails.logger.error "Fee Detail Import Failed: Malformed CSV - #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, errors: ["CSV文件格式错误: #{e.message}"] }
    rescue => e
      Rails.logger.error "Fee Detail Import Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, errors: ["导入过程中发生未知错误: #{e.message}"] }
    end
  end
  
  private
  
  def import_fee_detail(row, row_number)
    external_id = row['费用id']&.strip
    document_number = row['报销单单号']&.strip
    fee_type = row['费用类型']&.strip
    amount_str = row['原始金额']
    fee_date_str = row['费用发生日期']
    
    unless external_id.present? && document_number.present? && fee_type.present? && amount_str.present? && fee_date_str.present?
      @skipped_due_to_error_count += 1
      @errors << "行 #{row_number}: 缺少必要字段 (费用id, 报销单单号, 费用类型, 金额, 费用发生日期)"
      return
    end
    
    reimbursement = Reimbursement.find_by(invoice_number: document_number)
    unless reimbursement
      @unmatched_reimbursement_count += 1
      @unmatched_reimbursement_details << { row: row_number, external_fee_id: external_id, document_number: document_number, error: "关联的报销单不存在" }
      return
    end
    
    fee_detail = FeeDetail.find_or_initialize_by(external_fee_id: external_id)
    is_new_record = fee_detail.new_record?

    attributes = {
      document_number: document_number,
      fee_type: fee_type,
      amount: parse_decimal(amount_str),
      fee_date: parse_date(fee_date_str),
      verification_status: fee_detail.verification_status || FeeDetail::VERIFICATION_STATUS_PENDING, # Preserve status if existing, else default
      month_belonging: row['所属月']&.strip,
      first_submission_date: parse_datetime(row['首次提交日期']&.strip), # Ensure this is intended for fee_detail
      # New fields
      plan_or_pre_application: row['计划/预申请']&.strip,
      product: row['产品']&.strip,
      flex_field_11: row['弹性字段11']&.strip,
      flex_field_6: row['弹性字段6']&.strip,
      flex_field_7: row['弹性字段7']&.strip,
      expense_corresponding_plan: row['费用对应计划']&.strip,
      expense_associated_application: row['费用关联申请单']&.strip,
      # notes: fee_detail.notes # Preserve existing notes or update if CSV has notes
    }
    
    # Filter out nil values from attributes to prevent overwriting existing valid data with nil from CSV
    # unless you specifically want to nil out fields based on CSV.
    # For now, we'll assign all mapped attributes.
    fee_detail.assign_attributes(attributes)
    
    if fee_detail.save
      if is_new_record
        @created_count += 1
    else
        @updated_count += 1
      end
    else
      @skipped_due_to_error_count += 1
      @errors << "行 #{row_number} (费用ID: #{external_id}): 保存失败 - #{fee_detail.errors.full_messages.join(', ')}"
    end
  end
  
  def parse_date(date_string)
    return nil unless date_string.present?
    begin
      date_string.is_a?(Date) || date_string.is_a?(DateTime) ? date_string.to_date : Date.parse(date_string.to_s)
    rescue ArgumentError
      nil
    end
  end
  
  def parse_datetime(datetime_string)
    return nil unless datetime_string.present?
    begin
      datetime_string.is_a?(Date) || datetime_string.is_a?(DateTime) ? datetime_string : DateTime.parse(datetime_string.to_s)
    rescue ArgumentError
      nil
    end
  end
  
  def parse_decimal(decimal_string)
    return nil unless decimal_string.present?
    begin
      BigDecimal(decimal_string.to_s.gsub(',', '')) # 处理可能的逗号
    rescue ArgumentError
      nil
    end
  end
end