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
    @optimization_manager = SqliteOptimizationManager.new(level: :moderate)
  end

  def import(test_spreadsheet = nil)
    return { success: false, errors: ['文件不存在'] } unless @file.present?

    # 使用SQLite优化进行导入
    @optimization_manager.during_import do
      perform_import(test_spreadsheet)
    end
  end

  private

  def perform_import(test_spreadsheet = nil)
    file_path = if @file.respond_to?(:tempfile)
                  @file.tempfile.to_path.to_s
                elsif @file.respond_to?(:path)
                  @file.path
                else
                  @file.to_s # 如果是字符串，直接使用
                end
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
  rescue StandardError => e
    Rails.logger.error "Operation History Import Failed: #{e.message}\n#{e.backtrace.join("\n")}"
    { success: false, errors: ["导入过程中发生错误: #{e.message}"] }
  end

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
      @unmatched_histories << { row: row_number, document_number: document_number, error: '报销单不存在' }
      Rails.logger.warn "Skipping row #{row_number}: Reimbursement #{document_number} not found."
      return
    end

    operation_time = parse_datetime(operation_time_str)
    Rails.logger.info "Parsed operation_time: #{operation_time}"

    # 重复检查 (Req 14) - 改进版本
    if operation_time
      Rails.logger.info "Checking for duplicates for Doc: #{document_number}, Type: #{operation_type}, Operator: #{operator}, Time: #{operation_time}"

      # 使用更严格的查询条件检查重复
      existing_history = OperationHistory.find_by(
        document_number: document_number,
        operation_type: operation_type,
        operator: operator,
        operation_time: operation_time
      )

      if existing_history
        Rails.logger.info "Found exact duplicate: #{existing_history.id}"
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
      operation_node: row['操作节点'],

      # 映射所有CSV字段到数据库字段
      applicant: row['申请人'],
      employee_id: row['员工工号'],
      employee_company: row['员工公司'],
      employee_department: row['员工部门'],
      employee_department_path: row['员工部门路径'],
      document_company: row['员工单据公司'],
      document_department: row['员工单据部门'],
      document_department_path: row['员工单据部门路径'],
      submitter: row['提交人'],
      document_name: row['单据名称'],
      currency: row['币种'],
      amount: row['金额'].to_d,
      created_date: parse_datetime(row['创建日期'])
    )

    if operation_history.save
      @imported_count += 1

      # 自动分配审核员：如果报销单没有分配人，且操作类型是加签，且操作人匹配到admin_user，则自动指派
      assign_auditor_from_operation_history(operation_history, reimbursement)

      # 自动更新报销单状态：如果操作类型是"审批"且操作意见包含"审批通过"，尝试关闭报销单
      attempt_to_close_reimbursement(reimbursement) if operation_type == '审批' && notes&.include?('审批通过')
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

  def attempt_to_close_reimbursement(reimbursement)
    # 尝试关闭报销单，如果不满足条件close!方法会自动处理
    if reimbursement.can_be_closed?
      reimbursement.close!
      @updated_reimbursement_count += 1
      Rails.logger.info "  报销单 #{reimbursement.invoice_number || 'N/A'} 已自动关闭"
    else
      Rails.logger.debug "  报销单 #{reimbursement.invoice_number || 'N/A'} 不满足关闭条件：状态=#{reimbursement.status}, fee_details_verified=#{reimbursement.all_fee_details_verified?}"
    end
  end

  def assign_auditor_from_operation_history(operation_history, reimbursement)
    # 检查报销单是否没有分配人
    return if reimbursement.active_assignment.present?

    # 检查操作类型是否为加签
    return unless operation_history.operation_type == '加签'

    # 检查操作人是否匹配到admin_user
    operator = operation_history.operator
    return unless operator.present?

    auditor = AdminUserRepository.find_by_name_substring(operator)

    if auditor
      # 创建分配记录
      assignment = ReimbursementAssignment.new(
        reimbursement: reimbursement,
        assignee: auditor,
        assigner: @current_admin_user,
        is_active: true,
        notes: '自动分配：操作历史中检测到加签操作和操作人匹配'
      )

      if assignment.save
        Rails.logger.info "  自动分配成功：报销单 #{reimbursement.invoice_number} 通过操作历史分配给 #{auditor.name}"
      else
        Rails.logger.warn "  自动分配失败：#{assignment.errors.full_messages.join(', ')}"
      end
    else
      Rails.logger.debug "  未找到匹配的操作人：#{operator}"
    end
  end
end
