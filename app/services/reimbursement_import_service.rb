# app/services/reimbursement_import_service.rb
class ReimbursementImportService
  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @created_count = 0
    @updated_count = 0
    @error_count = 0
    @errors = []
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

    Rails.logger.debug "Importing Reimbursement #{invoice_number} (Row #{row_number})"
    Rails.logger.debug "  Original external_status: #{reimbursement.external_status.inspect}"
    Rails.logger.debug "  CSV '报销单状态' value: #{row['报销单状态'].inspect}"

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

    Rails.logger.debug "  external_status after assign_attributes: #{reimbursement.external_status.inspect}"
    Rails.logger.debug "  Reimbursement status BEFORE mapping logic: #{reimbursement.status.inspect}"

    # 应用新的状态逻辑：外部状态优先，手动覆盖保护
    external_status_from_csv = row['报销单状态']&.strip
    Rails.logger.debug "  CSV '报销单状态' stripped value: #{external_status_from_csv.inspect}"
    
    # Store the original status for logging
    original_internal_status = reimbursement.status
    Rails.logger.debug "  Reimbursement status BEFORE new logic: #{original_internal_status.inspect}"

    # Apply new status determination logic
    if is_new_record
      # For new records, start with pending and then apply business rules
      reimbursement.status = Reimbursement::STATUS_PENDING
      Rails.logger.debug "  Setting initial status to PENDING for new record"
    end
    
    # Apply the new status determination logic
    new_status = reimbursement.determine_internal_status_from_external(external_status_from_csv)
    
    # Only update status if it's different and not manually overridden
    if new_status != reimbursement.status && !reimbursement.manual_override?
      reimbursement.status = new_status
      Rails.logger.debug "  Updated status from #{original_internal_status} to #{new_status} based on external status"
    elsif reimbursement.manual_override?
      Rails.logger.debug "  Status change blocked by manual override flag"
    end
    
    # Update last_external_status for tracking
    reimbursement.last_external_status = external_status_from_csv
    
    Rails.logger.debug "  Reimbursement status AFTER new logic: #{reimbursement.status.inspect}"

    if reimbursement.save
      Rails.logger.debug "  Reimbursement saved successfully. Final external_status: #{reimbursement.external_status.inspect}, Final internal_status: #{reimbursement.status.inspect}"

      # 自动分配审核员：如果当前审批节点是审核，且当前审批人匹配到admin_user，则自动指派
      assign_auditor_if_needed(reimbursement, row)

      if is_new_record
        @created_count += 1
      else
        # If it's not a new record and it was saved successfully, count it as updated
        @updated_count += 1
      end
    else
      @error_count += 1
      error_messages = reimbursement.errors.full_messages.join(', ')
      @errors << "行 #{row_number} (单号: #{invoice_number}): #{error_messages}"
      Rails.logger.error "  Reimbursement save failed: #{error_messages}"
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

  def assign_auditor_if_needed(reimbursement, row)
    current_approval_node = row['当前审批节点']&.strip
    current_approver = row['当前审批人']&.strip

    return unless current_approval_node == '审核' && current_approver.present?

    # 查找匹配的审核员
    auditor = AdminUser.find_by_name_substring(current_approver)

    if auditor
      # 创建分配记录
      assignment = ReimbursementAssignment.new(
        reimbursement: reimbursement,
        assignee: auditor,
        assigner: @current_admin_user,
        is_active: true,
        notes: "自动分配：导入时检测到审核节点和审核人匹配"
      )

      if assignment.save
        Rails.logger.info "  自动分配成功：报销单 #{reimbursement.invoice_number} 分配给 #{auditor.name}"
      else
        Rails.logger.warn "  自动分配失败：#{assignment.errors.full_messages.join(', ')}"
      end
    else
      Rails.logger.debug "  未找到匹配的审核员：#{current_approver}"
    end
  end
end