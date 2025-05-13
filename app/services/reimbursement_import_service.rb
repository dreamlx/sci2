# app/services/reimbursement_import_service.rb
class ReimbursementImportService
  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @created_count = 0
    @updated_count = 0
    @error_count = 0
    @errors = []
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

      headers = sheet.row(1).map { |h| h.to_s.strip } # Standardize headers
      sheet.each_with_index do |row, idx|
        next if idx == 0 # Skip header row

        row_data = Hash[headers.zip(row)]
        import_reimbursement(row_data, idx + 1)
      end

      {
        success: true,
        created: @created_count,
        updated: @updated_count,
        errors: @error_count,
        error_details: @errors
      }
    rescue => e
      Rails.logger.error "Reimbursement Import Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, errors: ["导入过程中发生错误: #{e.message}"] }
    end
  end

  private

  def import_reimbursement(row, row_number)
    invoice_number = row['报销单单号']&.strip

    unless invoice_number.present?
      @error_count += 1
      @errors << "行 #{row_number}: 报销单单号不能为空"
      return
    end

    # According to invoice_number find or initialize reimbursement (Req 15)
    reimbursement = Reimbursement.find_or_initialize_by(invoice_number: invoice_number)
    is_new_record = reimbursement.new_record?

    # Map attributes from row data
    reimbursement.assign_attributes(
      document_name: row['单据名称'] || reimbursement.document_name,
      applicant: row['报销单申请人'] || reimbursement.applicant,
      applicant_id: row['报销单申请人工号'] || reimbursement.applicant_id,
      company: row['申请人公司'] || reimbursement.company,
      department: row['申请人部门'] || reimbursement.department,
      amount: row['报销金额（单据币种）'] || reimbursement.amount,
      receipt_status: parse_receipt_status(row['收单状态']) || reimbursement.receipt_status,
      receipt_date: parse_date(row['收单日期']) || reimbursement.receipt_date,
      submission_date: parse_date(row['提交报销日期']) || reimbursement.submission_date,
      is_electronic: row['单据标签']&.include?('全电子发票') || false, # Explicitly default to false
      external_status: row['报销单状态'] || reimbursement.external_status, # Store external status
      approval_date: parse_datetime(row['报销单审核通过日期']) || reimbursement.approval_date,
      approver_name: row['审核通过人'] || reimbursement.approver_name,
      # Optional add other fields
      related_application_number: row['关联申请单号'] || reimbursement.related_application_number,
      accounting_date: parse_date(row['记账日期']) || reimbursement.accounting_date,
      document_tags: row['单据标签'] || reimbursement.document_tags
    )

    # Set internal status for new records to pending always
    if is_new_record
      reimbursement.status = 'pending'
    end

    if reimbursement.save
      if is_new_record
        @created_count += 1
      else
        # If it's not a new record and it was saved successfully, count it as updated
        @updated_count += 1
      end
    else
      @error_count += 1
      @errors << "行 #{row_number} (单号: #{invoice_number}): #{reimbursement.errors.full_messages.join(', ')}"
    end
  end

  def parse_receipt_status(status)
    return nil unless status.present?
    status.include?('已收单') ? 'received' : 'pending'
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
end