# app/services/optimized_reimbursement_import_service.rb
class OptimizedReimbursementImportService
  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @batch_manager = BatchImportManager.new(Reimbursement, optimization_level: :moderate)
    @results = {
      success: false,
      created: 0,
      updated: 0,
      errors: 0,
      error_details: [],
      performance_stats: {}
    }
  end
  
  def import(test_spreadsheet = nil)
    return { success: false, errors: ["文件不存在"] } unless @file.present?
    
    begin
      # 1. 解析所有数据
      all_rows_data = parse_all_rows(test_spreadsheet)
      return { success: false, errors: ["没有有效数据"] } if all_rows_data.empty?
      
      # 2. 数据验证和预处理
      validated_data = validate_and_preprocess_data(all_rows_data)
      
      # 3. 批量处理（禁用回调以提升性能）
      disabled_callbacks = [
        [:save, :after, :update_status_based_on_fee_details],
        [:create, :after, :update_notification_status],
        [:update, :after, :update_notification_status]
      ]
      
      @batch_manager.batch_import_with_disabled_callbacks(validated_data, disabled_callbacks) do |batch|
        process_reimbursement_batch(batch)
      end
      
      # 4. 批量状态更新（在所有数据导入完成后）
      batch_update_statuses(validated_data)
      
      # 5. 收集性能统计
      @results[:performance_stats] = @batch_manager.performance_stats
      @results[:success] = true
      
      Rails.logger.info "Optimized reimbursement import completed: #{@results}"
      @results
      
    rescue Roo::FileNotFound => e
      Rails.logger.error "Optimized Reimbursement Import Failed: File not found - #{e.message}"
      { success: false, errors: ["导入文件未找到: #{e.message}"] }
    rescue CSV::MalformedCSVError => e
      Rails.logger.error "Optimized Reimbursement Import Failed: Malformed CSV - #{e.message}"
      { success: false, errors: ["CSV文件格式错误: #{e.message}"] }
    rescue => e
      Rails.logger.error "Optimized Reimbursement Import Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, errors: ["导入过程中发生错误: #{e.message}"] }
    end
  end
  
  # Make this method public for testing
  def batch_update_statuses(validated_data)
    # 批量更新状态（在所有数据导入完成后执行）
    Rails.logger.info "Starting batch status updates..."
    
    invoice_numbers = validated_data.map { |data| data[:invoice_number] }.uniq
    
    # 批量查询需要更新状态的报销单
    reimbursements_to_update = Reimbursement.where(invoice_number: invoice_numbers)
    
    updated_count = 0
    reimbursements_to_update.each do |reimbursement|
      external_status = validated_data.find { |d| d[:invoice_number] == reimbursement.invoice_number }&.dig(:external_status)
      
      if external_status.present?
        # 使用模型方法确定内部状态
        new_status = reimbursement.determine_internal_status_from_external(external_status)
        
        # 只有状态发生变化或外部状态更新时才保存
        if new_status != reimbursement.status || external_status != reimbursement.last_external_status
          reimbursement.update!(
            external_status: external_status,
            last_external_status: external_status,
            status: new_status
          )
          updated_count += 1
        end
      end
    end
    
    Rails.logger.info "Batch updated #{updated_count} reimbursement statuses"
  end
  
  private
  
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
  
  def validate_and_preprocess_data(all_rows_data)
    valid_data = []
    
    all_rows_data.each do |row_data|
      invoice_number = row_data['报销单单号']&.strip
      
      if invoice_number.blank?
        @results[:errors] += 1
        @results[:error_details] << "行 #{row_data[:row_number]}: 报销单单号不能为空"
        next
      end
      
      # 预处理数据
      processed_data = {
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
        # 元数据
        row_number: row_data[:row_number]
      }
      
      valid_data << processed_data
    end
    
    Rails.logger.info "Validated #{valid_data.size} records, #{@results[:errors]} errors"
    valid_data
  end
  
  def process_reimbursement_batch(batch)
    # 1. 批量查询现有记录
    invoice_numbers = batch.map { |data| data[:invoice_number] }.compact.uniq
    existing_reimbursements = @batch_manager.batch_find_existing(:invoice_number, invoice_numbers)
    
    # 2. 分离新增和更新数据
    new_records = []
    update_records = []
    
    batch.each do |data|
      invoice_number = data[:invoice_number]
      existing_record = existing_reimbursements[invoice_number]
      
      # 构建属性（移除元数据）
      attributes = data.except(:row_number)
      
      if existing_record
        # 更新记录：保留ID和创建时间
        update_records << attributes.merge(
          id: existing_record.id,
          created_at: existing_record.created_at
        )
      else
        # 新增记录：设置默认状态
        new_records << attributes.merge(
          status: Reimbursement::STATUS_PENDING
        )
      end
    end
    
    # 3. 批量执行数据库操作
    Rails.logger.info "Processing batch: #{new_records.size} new, #{update_records.size} updates"
    
    created_count = 0
    updated_count = 0
    
    if new_records.any?
      created_count = @batch_manager.batch_insert(new_records)
      @results[:created] += created_count
    end
    
    if update_records.any?
      updated_count = @batch_manager.batch_update(update_records, unique_by: :id)
      @results[:updated] += updated_count
    end
    
    Rails.logger.info "Batch processed: #{created_count} created, #{updated_count} updated"
  end
  
  
  def process_in_batches(data_array, &block)
    @batch_manager.send(:process_in_batches, data_array, &block)
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