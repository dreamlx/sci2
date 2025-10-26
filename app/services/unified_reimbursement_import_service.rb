# app/services/unified_reimbursement_import_service.rb
# 统一的报销导入服务 - 整合3个重复的报销导入服务
class UnifiedReimbursementImportService < BaseImportService
  # 字段映射配置 - 支持多种字段名变体
  FIELD_MAPPINGS = {
    invoice_number: %w[发票号 发票编号 invoice_number],
    applicant_name: %w[申请人姓名 申请人 applicant_name],
    department: %w[部门 department 部门名称],
    amount: %w[金额 amount 申请金额 报销金额],
    description: %w[描述 description 事由 说明],
    application_date: %w[申请日期 application_date 申请时间 报销日期],
    expense_type: %w[费用类型 expense_type 费用分类],
    project_code: %w[项目代码 project_code 项目编号]
  }.freeze

  def initialize(file, current_admin_user)
    super(file, current_admin_user)
    @sqlite_manager = SqliteOptimizationManager.new(level: :moderate)
    @updated_count = 0
    @results = {
      success: false,
      created: 0,
      updated: 0,
      errors: 0,
      error_details: []
    }
  end

  def import(test_spreadsheet = nil)
    return { success: false, errors: ['文件不存在'] } unless @file.present?

    # 使用SQLite优化管理器进行批量导入
    @sqlite_manager.during_import do
      perform_import(test_spreadsheet)
    end
  end

  private

  def perform_import(test_spreadsheet)
    # 1. 解析所有数据
    parse_result = parse_file(test_spreadsheet)
    return parse_result unless parse_result[:success]

    all_rows_data = parse_all_rows_data(parse_result[:sheet], parse_result[:headers])
    return format_result.merge(success: false, errors: ['没有有效数据']) if all_rows_data.empty?

    # 2. 预处理和验证数据
    validated_data = validate_and_prepare_data(all_rows_data)
    return format_result.merge(success: false) if validated_data.empty?

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
          reimbursement_id: existing_record.id,
          existing_record: existing_record
        )
      else
        # 新增记录
        new_records << data
      end
    end

    # 5. 批量处理
    process_new_records(new_records)
    process_update_records(update_records)

    # 6. 更新统计信息
    @created_count = new_records.length
    @updated_count = update_records.length
    @error_count = @errors.length

    format_result(
      created: @created_count,
      updated: @updated_count,
      total_processed: (new_records.length + update_records.length)
    )
  end

  def parse_all_rows_data(sheet, headers)
    all_rows_data = []

    process_rows(sheet, headers) do |row_data, row_number|
      processed_data = process_row_data(row_data, row_number)
      all_rows_data << processed_data if processed_data
    end

    all_rows_data
  end

  def process_row_data(row_data, row_number)
    begin
      # 提取和映射字段
      processed_data = {
        row_number: row_number,
        invoice_number: extract_field_value(row_data, :invoice_number),
        applicant_name: extract_field_value(row_data, :applicant_name),
        department: extract_field_value(row_data, :department),
        amount: parse_amount(extract_field_value(row_data, :amount)),
        description: extract_field_value(row_data, :description),
        application_date: parse_date_field(extract_field_value(row_data, :application_date)),
        expense_type: extract_field_value(row_data, :expense_type),
        project_code: extract_field_value(row_data, :project_code),
        raw_data: row_data
      }

      # 验证必需字段
      if processed_data[:invoice_number].blank?
        @errors << "第#{row_number}行: 发票号为必填项"
        return nil
      end

      if processed_data[:applicant_name].blank?
        @errors << "第#{row_number}行: 申请人为必填项"
        return nil
      end

      if processed_data[:amount].nil? || processed_data[:amount] <= 0
        @errors << "第#{row_number}行: 金额必须大于0"
        return nil
      end

      processed_data
    rescue => e
      handle_error(e, message: "处理第#{row_number}行数据时出错", reraise: false)
      nil
    end
  end

  def validate_and_prepare_data(all_rows_data)
    # 检查重复发票号
    invoice_numbers = all_rows_data.map { |data| data[:invoice_number] }
    duplicate_invoices = invoice_numbers.group_by(&:itself)
                                     .select { |_, invoices| invoices.length > 1 }
                                     .keys

    if duplicate_invoices.any?
      @errors << "发现重复的发票号: #{duplicate_invoices.join(', ')}"
      return []
    end

    all_rows_data
  end

  def process_new_records(new_records)
    return if new_records.empty?

    # 批量创建报销单
    reimbursements = new_records.map do |record|
      Reimbursement.new(
        invoice_number: record[:invoice_number],
        applicant: record[:applicant_name],
        department: record[:department],
        amount: record[:amount],
        submission_date: record[:application_date] || Date.current,
        status: 'pending'
      )
    end

    # 使用批量插入优化
    Reimbursement.insert_all(reimbursements.map(&:attributes))
  end

  def process_update_records(update_records)
    return if update_records.empty?

    update_records.each do |record|
      reimbursement = record[:existing_record]

      # 更新字段
      reimbursement.assign_attributes(
        applicant: record[:applicant_name],
        department: record[:department],
        amount: record[:amount],
        submission_date: record[:application_date] || reimbursement.submission_date
      )

      unless reimbursement.save
        @errors << "更新发票号 #{record[:invoice_number]} 失败: #{reimbursement.errors.full_messages.join(', ')}"
      end
    end
  end

  def extract_field_value(row_data, field_type)
    field_names = FIELD_MAPPINGS[field_type] || []
    field_names.each do |field_name|
      value = row_data[field_name]&.to_s&.strip
      return value if value.present?
    end
    nil
  end

  def parse_amount(amount_string)
    return nil if amount_string.blank?

    # 移除非数字字符（除了小数点）
    cleaned_amount = amount_string.to_s.gsub(/[^\d.]/, '')
    return nil if cleaned_amount.blank?

    cleaned_amount.to_f
  end

  def parse_date_field(date_string)
    return nil if date_string.blank?

    begin
      # 尝试多种日期格式
      Date.parse(date_string) ||
      Time.parse(date_string) ||
      DateTime.parse(date_string)
    rescue ArgumentError
      Rails.logger.warn "无法解析日期格式: #{date_string}"
      nil
    end
  end
end