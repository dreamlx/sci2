# app/services/simple_batch_reimbursement_import_service.rb
class SimpleBatchReimbursementImportService
  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @sqlite_manager = SqliteOptimizationManager.new(level: :moderate)
    @results = {
      success: false,
      created: 0,
      updated: 0,
      errors: 0,
      error_details: []
    }
  end
  
  def import(test_spreadsheet = nil)
    return { success: false, errors: ["文件不存在"] } unless @file.present?
    
    @sqlite_manager.during_import do
      perform_batch_import(test_spreadsheet)
    end
  end
  
  private
  
  def perform_batch_import(test_spreadsheet)
    begin
      # 1. 解析所有数据
      all_rows_data = parse_all_rows(test_spreadsheet)
      return @results.merge(success: false, errors: ["没有有效数据"]) if all_rows_data.empty?
      
      # 2. 预处理和验证数据
      validated_data = validate_and_prepare_data(all_rows_data)
      return @results.merge(success: false) if validated_data.empty?
      
      # 3. 批量查询现有记录
      invoice_numbers = validated_data.map { |data| data[:invoice_number] }.uniq
      existing_reimbursements = Reimbursement.where(invoice_number: invoice_numbers)
                                            .index_by(&:invoice_number)
      
      # 4. 分离新增和更新数据
      new_records = []
      update_records = []
      
      validated_data.each do |data|
        invoice_number = data[:invoice_number]
        existing_record = existing_reimbursements[invoice_number]
        
        if existing_record
          # 更新记录
          update_records << data.merge(
            id: existing_record.id,
            created_at: existing_record.created_at,
            updated_at: Time.current
          )
        else
          # 新增记录
          new_records << data.merge(
            created_at: Time.current,
            updated_at: Time.current
          )
        end
      end
      
      # 5. 执行批量操作
      ActiveRecord::Base.transaction do
        if new_records.any?
          Rails.logger.info "Batch inserting #{new_records.size} new reimbursements"
          Reimbursement.insert_all(new_records)
          @results[:created] = new_records.size
        end
        
        if update_records.any?
          Rails.logger.info "Batch updating #{update_records.size} existing reimbursements"
          Reimbursement.upsert_all(update_records, unique_by: :id)
          @results[:updated] = update_records.size
        end
      end
      
      @results[:success] = true
      Rails.logger.info "Simple batch import completed: #{@results}"
      @results
      
    rescue => e
      Rails.logger.error "Simple Batch Import Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      @results.merge(success: false, errors: 1, error_details: [e.message])
    end
  end
  
  def parse_all_rows(test_spreadsheet)
    file_path = @file.respond_to?(:tempfile) ? @file.tempfile.to_path.to_s : @file.path
    extension = File.extname(file_path).delete('.').downcase.to_sym
    spreadsheet = test_spreadsheet || Roo::Spreadsheet.open(file_path, extension: extension)
    sheet = spreadsheet.respond_to?(:sheet) ? spreadsheet.sheet(0) : spreadsheet
    
    headers = sheet.row(1).map { |h| h.to_s.strip }
    
    # 验证必要的列
    expected_headers = ['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门', '报销金额（单据币种）', '报销单状态']
    missing_headers = expected_headers - headers
    
    unless missing_headers.empty?
      raise ArgumentError, "缺少必要的列: #{missing_headers.join(', ')}"
    end
    
    # 解析所有行数据
    rows_data = []
    sheet.each_with_index do |row, idx|
      next if idx == 0 # Skip header row
      
      row_data = Hash[headers.zip(row)]
      row_data[:row_number] = idx + 1
      rows_data << row_data
    end
    
    Rails.logger.info "Parsed #{rows_data.size} rows from import file"
    rows_data
  end
  
  def validate_and_prepare_data(all_rows_data)
    valid_data = []
    
    all_rows_data.each do |row_data|
      invoice_number = row_data['报销单单号']&.strip
      
      if invoice_number.blank?
        @results[:errors] += 1
        @results[:error_details] << "行 #{row_data[:row_number]}: 报销单单号不能为空"
        next
      end
      
      # 构建记录属性
      attributes = {
        invoice_number: invoice_number,
        document_name: row_data['单据名称'],
        applicant: row_data['报销单申请人'],
        applicant_id: row_data['报销单申请人工号'],
        company: row_data['申请人公司'],
        department: row_data['申请人部门'],
        amount: row_data['报销金额（单据币种）'],
        receipt_status: parse_receipt_status(row_data['收单状态']),
        receipt_date: parse_date(row_data['收单日期']),
        submission_date: parse_date(row_data['提交报销日期']),
        is_electronic: row_data['单据标签']&.include?('全电子发票') || false,
        external_status: row_data['报销单状态'],
        approval_date: parse_datetime(row_data['报销单审核通过日期']),
        approver_name: row_data['审核通过人'],
        related_application_number: row_data['关联申请单号'],
        accounting_date: parse_date(row_data['记账日期']),
        document_tags: row_data['单据标签'],
        # ERP fields
        erp_current_approval_node: row_data['当前审批节点'],
        erp_current_approver: row_data['当前审批人'],
        erp_flexible_field_2: row_data['弹性字段2'],
        erp_node_entry_time: parse_datetime(row_data['当前审批节点转入时间']),
        erp_first_submitted_at: parse_datetime(row_data['首次提交时间']),
        erp_flexible_field_8: row_data['弹性字段8'],
        # 默认状态
        status: Reimbursement::STATUS_PENDING
      }
      
      valid_data << attributes
    end
    
    Rails.logger.info "Validated #{valid_data.size} records, #{@results[:errors]} errors"
    valid_data
  end
  
  # 解析方法（保持与原始服务一致）
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