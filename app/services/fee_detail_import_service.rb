# app/services/fee_detail_import_service.rb
require 'securerandom'

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
    @optimization_manager = SqliteOptimizationManager.new(level: :moderate)
  end
  
  def import(test_spreadsheet = nil)
    return { success: false, errors: ["文件不存在"] } unless @file.present?
    
    # 使用SQLite优化进行导入
    @optimization_manager.during_import do
      perform_import(test_spreadsheet)
    end
  end
  
  private
  
  def perform_import(test_spreadsheet = nil)
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
      # Validate essential headers (费用id is optional for backward compatibility)
      expected_headers = ['报销单单号', '费用类型', '原始金额', '费用发生日期'] # Add other essential headers if any
      missing_headers = expected_headers - headers
      unless missing_headers.empty?
        return { success: false, errors: ["CSV文件缺少必要的列: #{missing_headers.join(', ')}"] }
      end

      sheet.each_with_index do |row, idx|
        next if idx == 0 # Skip header row
        
        row_data = Hash[headers.zip(row)]
        import_fee_detail(row_data, idx + 1)
      end
      
      # Limit the amount of data returned to prevent session overflow
      # Store only counts and a limited number of error messages
      error_summary = @errors.empty? ? [] : @errors.take(10)
      if @errors.size > 10
        error_summary << "... and #{@errors.size - 10} more errors"
      end
      
      {
        success: @errors.empty?,
        created: @created_count,
        updated: @updated_count,
        unmatched_reimbursement: @unmatched_reimbursement_count,
        skipped_errors: @skipped_due_to_error_count,
        error_details: error_summary,
        # Don't include the full unmatched_reimbursement_details array to save space
        unmatched_count: @unmatched_reimbursement_details.size
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
  
  def import_fee_detail(row, row_number)
    external_id = row['费用id']&.to_s&.strip
    document_number = row['报销单单号']&.to_s&.strip
    fee_type = row['费用类型']&.to_s&.strip
    amount_str = row['原始金额']
    fee_date_str = row['费用发生日期']

    # external_id is optional for backward compatibility
    # Generate a unique ID if not provided
    if external_id.blank?
      external_id = "AUTO_#{document_number}_#{SecureRandom.hex(4)}"
    end
    
    # 检查其他必要字段
    unless document_number.present? && fee_type.present? && amount_str.present? && fee_date_str.present?
      @skipped_due_to_error_count += 1
      @errors << "行 #{row_number}: 缺少必要字段 (报销单单号, 费用类型, 金额, 费用发生日期)"
      return
    end
    
    # 检查报销单是否存在
    reimbursement = Reimbursement.find_by(invoice_number: document_number)
    unless reimbursement
      @unmatched_reimbursement_count += 1
      @unmatched_reimbursement_details << { row: row_number, external_fee_id: external_id, document_number: document_number, error: "关联的报销单不存在" }
      return
    end
    
    # 简化重复检测逻辑：仅使用 external_fee_id 作为唯一标识符
    existing_fee_detail = FeeDetail.find_by(external_fee_id: external_id)
    
    # 检查现有费用明细是否具有不同的document_number
    if existing_fee_detail && existing_fee_detail.document_number != document_number
      @skipped_due_to_error_count += 1
      @errors << "行 #{row_number} (费用ID: #{external_id}): 关联的报销单号不匹配 - 现有: #{existing_fee_detail.document_number}, 导入: #{document_number}"
      return
    end
    
    # 如果找到现有记录，则更新；否则创建新记录
    fee_detail = existing_fee_detail || FeeDetail.new(external_fee_id: external_id)
    is_new_record = fee_detail.new_record?

    attributes = {
      document_number: document_number,
      fee_type: fee_type,
      amount: parse_decimal(amount_str),
      fee_date: parse_date(fee_date_str),
      verification_status: fee_detail.verification_status || FeeDetail::VERIFICATION_STATUS_PENDING, # 保留现有状态，否则默认
      month_belonging: row['所属月']&.to_s&.strip,
      first_submission_date: parse_datetime(row['首次提交日期']&.to_s&.strip),
      # 新字段
      plan_or_pre_application: row['计划/预申请']&.to_s&.strip,
      product: row['产品']&.to_s&.strip,
      flex_field_11: row['弹性字段11']&.to_s&.strip,
      flex_field_6: row['弹性字段6(报销单)']&.to_s&.strip,
      flex_field_7: row['弹性字段7(报销单)']&.to_s&.strip,
      expense_corresponding_plan: row['费用对应计划']&.to_s&.strip,
      expense_associated_application: row['费用关联申请单']&.to_s&.strip,
    }
    
    fee_detail.assign_attributes(attributes)
    
    if fee_detail.save
      if is_new_record
        @created_count += 1
        Rails.logger.info "创建新费用明细: external_fee_id=#{external_id}, document_number=#{document_number}"
      else
        @updated_count += 1
        Rails.logger.info "更新现有费用明细: external_fee_id=#{external_id}, document_number=#{document_number}"
      end
      
      # 更新报销单状态，确保与费用明细状态保持一致
      reimbursement.update_status_based_on_fee_details!
      
      # 如果我们更改了document_number，则更新旧报销单的状态
      if existing_fee_detail && existing_fee_detail.document_number != document_number && defined?(old_reimbursement) && old_reimbursement
        # 更新旧报销单的状态，因为费用明细已被移除
        old_reimbursement.update_status_based_on_fee_details!
      end
    else
      @skipped_due_to_error_count += 1
      @errors << "行 #{row_number} (费用ID: #{external_id}): 保存失败 - #{fee_detail.errors.full_messages.join(', ')}"
      Rails.logger.error "保存费用明细失败: external_fee_id=#{external_id}, errors=#{fee_detail.errors.full_messages.join(', ')}"
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
    return 0 unless decimal_string.present?
    begin
      value = BigDecimal(decimal_string.to_s.gsub(',', '')) # 处理可能的逗号
      # If parsing succeeds but results in 0 or negative, return 0
      value.positive? ? value : 0
    rescue ArgumentError
      0 # Return 0 instead of nil for invalid values
    end
  end
end