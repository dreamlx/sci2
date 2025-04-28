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
      spreadsheet = test_spreadsheet || Roo::Spreadsheet.open(@file.path)
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
    
    unless document_number.present? && operation_type.present? && operation_time_str.present? && operator.present?
      @error_count += 1
      @errors << "行 #{row_number}: 缺少必要字段 (单据编号, 操作类型, 操作日期, 操作人)"
      return
    end
    
    # 查找报销单
    reimbursement = Reimbursement.find_by(invoice_number: document_number)
    
    unless reimbursement
      @unmatched_histories << { row: row_number, document_number: document_number, error: "报销单不存在" }
      return
    end
    
    operation_time = parse_datetime(operation_time_str)
    
    # 重复检查 (Req 14)
    if operation_time && OperationHistory.exists?(
        document_number: document_number,
        operation_type: operation_type,
        operation_time: operation_time,
        operator: operator
      )
      @skipped_count += 1
      return # 跳过重复记录
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
      
      # 检查此历史记录是否关闭报销单 (Req 158)
      if operation_type == '审批' && notes == '审批通过'
        # 只有当报销单不是已关闭状态时才尝试关闭它
        if !reimbursement.closed?
          begin
            # 记录之前的状态
            previous_status = reimbursement.status
            
            # 尝试关闭报销单
            reimbursement.close!
            
            # 只有当状态实际发生变化时才增加计数
            if reimbursement.status != previous_status
              @updated_reimbursement_count += 1
            end
          rescue StateMachines::InvalidTransition => e
            Rails.logger.warn "Could not close Reimbursement #{reimbursement.id} based on history ID #{operation_history.id}: #{e.message}"
          end
        end
      end
    else
      @error_count += 1
      @errors << "行 #{row_number} (单号: #{document_number}): #{operation_history.errors.full_messages.join(', ')}"
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