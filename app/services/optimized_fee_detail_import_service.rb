# app/services/optimized_fee_detail_import_service.rb
class OptimizedFeeDetailImportService
  def initialize(file, current_admin_user, skip_existing: false)
    @file = file
    @current_admin_user = current_admin_user
    @skip_existing = skip_existing
    @batch_manager = BatchImportManager.new(FeeDetail, optimization_level: :moderate)
    @results = {
      success: false,
      created: 0,
      updated: 0,
      skipped: 0,
      errors: 0,
      error_details: [],
      unmatched_reimbursement: 0,
      performance_stats: {}
    }
    Current.admin_user = current_admin_user
  end
  
  def import(test_spreadsheet = nil)
    return { success: false, errors: ["文件不存在"] } unless @file.present?
    
    begin
      # 1. 解析所有数据
      all_rows_data = parse_all_rows(test_spreadsheet)
      return { success: false, errors: ["没有有效数据"] } if all_rows_data.empty?
      
      # 2. 预加载关联数据
      preload_associations(all_rows_data)
      
      # 3. 数据验证和预处理
      validated_data = validate_and_preprocess_data(all_rows_data)
      
      # 4. 批量处理（禁用回调以提升性能）
      disabled_callbacks = [
        [:save, :after, :update_reimbursement_status]
      ]
      
      @batch_manager.batch_import_with_disabled_callbacks(validated_data, disabled_callbacks) do |batch|
        process_fee_detail_batch(batch)
      end
      
      # 5. 批量更新报销单状态
      batch_update_reimbursement_statuses(validated_data)
      
      # 6. 收集性能统计
      @results[:performance_stats] = @batch_manager.performance_stats
      @results[:success] = @results[:errors] == 0
      
      Rails.logger.info "Optimized fee detail import completed: #{@results}"
      @results
      
    rescue Roo::FileNotFound => e
      Rails.logger.error "Optimized Fee Detail Import Failed: File not found - #{e.message}"
      { success: false, errors: ["导入文件未找到: #{e.message}"] }
    rescue CSV::MalformedCSVError => e
      Rails.logger.error "Optimized Fee Detail Import Failed: Malformed CSV - #{e.message}"
      { success: false, errors: ["CSV文件格式错误: #{e.message}"] }
    rescue => e
      Rails.logger.error "Optimized Fee Detail Import Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, errors: ["导入过程中发生错误: #{e.message}"] }
    end
  end
  
  private
  
  def parse_all_rows(test_spreadsheet)
    file_path = @file.respond_to?(:tempfile) ? @file.tempfile.to_path.to_s : @file.path
    extension = File.extname(file_path).delete('.').downcase.to_sym
    spreadsheet = test_spreadsheet || Roo::Spreadsheet.open(file_path, extension: extension)
    sheet = spreadsheet.respond_to?(:sheet) ? spreadsheet.sheet(0) : spreadsheet
    
    headers = sheet.row(1).map { |h| h.to_s.strip }
    
    # 验证必要的列
    expected_headers = ['报销单单号', '费用id', '费用类型', '原始金额', '费用发生日期']
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
    
    Rails.logger.info "Parsed #{rows_data.size} fee detail rows from import file"
    rows_data
  end
  
  def preload_associations(all_rows_data)
    # 预加载所有需要的报销单和费用明细
    document_numbers = all_rows_data.map { |row| row['报销单单号']&.strip }.compact.uniq
    external_fee_ids = all_rows_data.map { |row| row['费用id']&.strip }.compact.uniq
    fee_type_names = all_rows_data.map { |row| row['费用类型']&.strip }.compact.uniq
    
    Rails.logger.info "Preloading associations: #{document_numbers.size} reimbursements, #{external_fee_ids.size} fee details, #{fee_type_names.size} fee types"
    
    @existing_reimbursements = Reimbursement.where(invoice_number: document_numbers).index_by(&:invoice_number)
    @existing_fee_details = @batch_manager.batch_find_existing(:external_fee_id, external_fee_ids)
    @fee_types_map = FeeType.where(name: fee_type_names).index_by(&:name)
    
    Rails.logger.info "Preloaded #{@existing_reimbursements.size} existing reimbursements, #{@existing_fee_details.size} existing fee details, #{@fee_types_map.size} fee types"
  end
  
  def validate_and_preprocess_data(all_rows_data)
    valid_data = []
    
    all_rows_data.each do |row_data|
      external_id = row_data['费用id']&.to_s&.strip
      document_number = row_data['报销单单号']&.to_s&.strip
      fee_type = row_data['费用类型']&.to_s&.strip
      amount_str = row_data['原始金额']
      fee_date_str = row_data['费用发生日期']
      
      # 验证必要字段
      if external_id.blank?
        @results[:errors] += 1
        @results[:error_details] << "行 #{row_data[:row_number]}: 缺少必要字段 (费用id)"
        next
      end
      
      unless document_number.present? && fee_type.present? && amount_str.present? && fee_date_str.present?
        @results[:errors] += 1
        @results[:error_details] << "行 #{row_data[:row_number]}: 缺少必要字段 (报销单单号, 费用类型, 金额, 费用发生日期)"
        next
      end
      
      # 验证报销单存在
      unless @existing_reimbursements[document_number]
        @results[:unmatched_reimbursement] += 1
        @results[:error_details] << "行 #{row_data[:row_number]}: 关联的报销单不存在 (#{document_number})"
        next
      end
      
      # 预处理数据
      processed_data = {
        external_fee_id: external_id,
        document_number: document_number,
        fee_type: fee_type,
        amount: parse_decimal(amount_str),
        fee_date: parse_date(fee_date_str),
        verification_status: FeeDetail::VERIFICATION_STATUS_PENDING,
        month_belonging: row_data['所属月']&.to_s&.strip,
        first_submission_date: parse_datetime(row_data['首次提交日期']&.to_s&.strip),
        plan_or_pre_application: row_data['计划/预申请']&.to_s&.strip,
        product: row_data['产品']&.to_s&.strip,
        flex_field_11: row_data['弹性字段11']&.to_s&.strip,
        flex_field_6: row_data['弹性字段6(报销单)']&.to_s&.strip,
        flex_field_7: row_data['弹性字段7(报销单)']&.to_s&.strip,
        expense_corresponding_plan: row_data['费用对应计划']&.to_s&.strip,
        expense_associated_application: row_data['费用关联申请单']&.to_s&.strip,
        # 元数据
        row_number: row_data[:row_number]
      }
      
      # 动态填充个人日常报销单的 flex_field_7
      reimbursement = @existing_reimbursements[document_number]
      if reimbursement&.document_name&.include?('个人日常和差旅（含小沟会）报销单') && processed_data[:flex_field_7].blank?
        fee_type_record = @fee_types_map[fee_type]
        if fee_type_record
          processed_data[:flex_field_7] = fee_type_record.meeting_name
          Rails.logger.info "Row #{row_data[:row_number]}: Patched flex_field_7 with '#{fee_type_record.meeting_name}' for document #{document_number}"
        end
      end
      
      valid_data << processed_data
    end
    
    Rails.logger.info "Validated #{valid_data.size} fee detail records, #{@results[:errors]} errors"
    valid_data
  end
  
  def process_fee_detail_batch(batch)
    # 1. 分离新增、更新和跳过的数据
    new_records = []
    update_records = []
    skipped_count = 0
    
    batch.each do |data|
      external_fee_id = data[:external_fee_id]
      existing_record = @existing_fee_details[external_fee_id]
      
      # 构建属性（移除元数据）
      attributes = data.except(:row_number)
      
      if existing_record
        if @skip_existing
          # 跳过已存在的记录
          skipped_count += 1
        else
          # 更新记录：保留ID和创建时间，保留现有验证状态
          update_records << attributes.merge(
            id: existing_record.id,
            created_at: existing_record.created_at,
            verification_status: existing_record.verification_status || attributes[:verification_status]
          )
        end
      else
        # 新增记录
        new_records << attributes
      end
    end
    
    # 2. 批量执行数据库操作
    created_count = @batch_manager.batch_insert(new_records)
    updated_count = @batch_manager.batch_update(update_records, unique_by: :id)
    
    @results[:created] += created_count
    @results[:updated] += updated_count
    @results[:skipped] += skipped_count
    
    Rails.logger.info "Fee detail batch processed: #{created_count} created, #{updated_count} updated, #{skipped_count} skipped"
  end
  
  def batch_update_reimbursement_statuses(validated_data)
    # 批量更新相关报销单的状态
    Rails.logger.info "Starting batch reimbursement status updates..."
    
    document_numbers = validated_data.map { |data| data[:document_number] }.uniq
    
    # 批量更新报销单状态
    document_numbers.each do |document_number|
      reimbursement = @existing_reimbursements[document_number]
      reimbursement&.update_status_based_on_fee_details!
    end
    
    Rails.logger.info "Updated statuses for #{document_numbers.size} reimbursements"
  end
  
  # 解析方法（保持与原始服务一致）
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
      value = BigDecimal(decimal_string.to_s.gsub(',', ''))
      value.positive? ? value : 0
    rescue ArgumentError
      0
    end
  end
end