# app/services/fee_detail_import_service.rb
class FeeDetailImportService
  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @imported_count = 0
    @skipped_count = 0 # 用于重复记录
    @error_count = 0
    @errors = []
    @unmatched_details = []
    Current.admin_user = current_admin_user # 设置 Current.admin_user 用于回调
  end
  
  def import(test_spreadsheet = nil)
    return { success: false, errors: ["文件不存在"] } unless @file.present?
    
    begin
      spreadsheet = test_spreadsheet || Roo::Spreadsheet.open(@file.tempfile.to_path.to_s, extension: :csv)
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
        import_fee_detail(row_data, idx + 1)
      end
      
      {
        success: true,
        imported: @imported_count,
        skipped: @skipped_count,
        unmatched: @unmatched_details.count,
        errors: @error_count,
        error_details: @errors,
        unmatched_details: @unmatched_details
      }
    rescue => e
      Rails.logger.error "Fee Detail Import Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, errors: ["导入过程中发生错误: #{e.message}"] }
    end
  end
  
  private
  
  def import_fee_detail(row, row_number)
    document_number = row['报销单单号']&.strip
    fee_type = row['费用类型']&.strip
    amount_str = row['原始金额']
    fee_date_str = row['费用发生日期']
    
    unless document_number.present? && fee_type.present? && amount_str.present? && fee_date_str.present?
      @error_count += 1
      @errors << "行 #{row_number}: 缺少必要字段 (报销单单号, 费用类型, 金额, 费用发生日期)"
      return
    end
    
    # 查找报销单
    reimbursement = Reimbursement.find_by(invoice_number: document_number)
    
    unless reimbursement
      @unmatched_details << { row: row_number, document_number: document_number, error: "报销单不存在" }
      return
    end
    
    amount = parse_decimal(amount_str)
    fee_date = parse_date(fee_date_str)
    
    # 重复检查 (Req 14)
    if fee_date && amount && FeeDetail.exists?(
        document_number: document_number,
        fee_type: fee_type,
        amount: amount,
        fee_date: fee_date
      )
      @skipped_count += 1
      return # 跳过重复记录
    end
    
    # 创建费用明细
    fee_detail = FeeDetail.new(
      document_number: document_number,
      fee_type: fee_type,
      amount: amount,
      currency: row['原始币种'] || 'CNY',
      fee_date: fee_date,
      payment_method: row['弹性字段11'],
      verification_status: FeeDetail::VERIFICATION_STATUS_PENDING, # Req 8
      month_belonging: row['所属月'],
      first_submission_date: parse_datetime(row['首次提交日期'])
    )
    
    if fee_detail.save
      @imported_count += 1
    else
      @error_count += 1
      @errors << "行 #{row_number} (单号: #{document_number}): #{fee_detail.errors.full_messages.join(', ')}"
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