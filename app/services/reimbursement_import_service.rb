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
      sheet = if spreadsheet.respond_to?(:sheet)
                spreadsheet.sheet(0)
              else
                spreadsheet
              end

      headers = sheet.row(1).map { |h| h.to_s.strip }
      # Validate essential headers
      expected_headers = ['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门', '报销金额（单据币种）', '报销单状态'] # Add other absolutely essential headers
      missing_headers = expected_headers - headers
      unless missing_headers.empty?
        return {
          success: false,
          created: 0,
          updated: 0,
          errors: 1,
          error_details: ["缺少必要的列: #{missing_headers.join(', ')}"]
        }
      end

      sheet.each_with_index do |row, idx|
        next if idx == 0 # Skip header row

        row_data = Hash[headers.zip(row)]
        import_reimbursement(row_data, idx + 1)
      end

      {
        success: true, # 总是返回成功，即使有错误也算成功导入
        created: @created_count,
        updated: @updated_count,
        errors: @error_count, # Or @errors.count for number of error messages
        error_details: @errors # Array of detailed error messages
      }
    rescue Roo::FileNotFound => e
      Rails.logger.error "Reimbursement Import Failed: File not found - #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, created: 0, updated: 0, errors: 1, error_details: ["导入文件未找到: #{e.message}"] }
    rescue CSV::MalformedCSVError => e # Ensure Roo re-raises this or handles it appropriately if it wraps CSV
      Rails.logger.error "Reimbursement Import Failed: Malformed CSV - #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, created: 0, updated: 0, errors: 1, error_details: ["CSV文件格式错误: #{e.message}"] }
    rescue => e
      Rails.logger.error "Reimbursement Import Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, created: 0, updated: 0, errors: 1, error_details: ["导入过程中发生错误: #{e.message}"] }
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
      # Additional fields from CSV
      related_application_number: row['关联申请单号'] || reimbursement.related_application_number,
      accounting_date: parse_date(row['记账日期']) || reimbursement.accounting_date,
      document_tags: row['单据标签'] || reimbursement.document_tags,
      
      # ERP fields from CSV
      erp_current_approval_node: row['当前审批节点'] || reimbursement.erp_current_approval_node,
      erp_current_approver: row['当前审批人'] || reimbursement.erp_current_approver,
      erp_flexible_field_2: row['弹性字段2'] || reimbursement.erp_flexible_field_2,
      erp_node_entry_time: parse_datetime(row['当前审批节点转入时间']) || reimbursement.erp_node_entry_time,
      erp_first_submitted_at: parse_datetime(row['首次提交时间']) || reimbursement.erp_first_submitted_at,
      erp_flexible_field_8: row['弹性字段8'] || reimbursement.erp_flexible_field_8
    )

    # 根据外部状态设置内部状态
    if is_new_record
      # 所有新记录的状态都设置为 pending，不考虑外部状态
      # 这样符合状态机的初始状态设置，也符合业务预期
      reimbursement.status = Reimbursement::STATUS_PENDING
    else
      # 现有记录保持原状态，除非外部状态明确指示为已完成
      # 但即使外部状态为已完成，也需要检查是否所有费用明细都已验证
      if row['报销单状态'].present? && map_external_status_to_internal(row['报销单状态']) == Reimbursement::STATUS_CLOSED
        # 不直接设置状态，而是使用 close! 方法，它会检查是否所有费用明细都已验证
        # 如果不能关闭，则设置为处理中状态
        unless reimbursement.close!
          reimbursement.status = Reimbursement::STATUS_PROCESSING
        end
      end
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
  
  def map_external_status_to_internal(external_status)
    return nil unless external_status.present?
    
    case external_status
    when /已完成/, /已审批/, /已审核/, /已通过/, /已结束/, /已关闭/, /已付款/
      Reimbursement::STATUS_CLOSED
    when /处理中/, /审核中/, /审批中/
      Reimbursement::STATUS_PROCESSING
    when /待审批/
      Reimbursement::STATUS_PENDING
    else
      Reimbursement::STATUS_PENDING
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