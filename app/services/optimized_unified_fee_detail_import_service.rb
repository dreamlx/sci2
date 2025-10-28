# app/services/optimized_unified_fee_detail_import_service.rb
# 优化版统一费用明细导入服务 - 继承BaseImportService并集成性能优化
class OptimizedUnifiedFeeDetailImportService < BaseImportService
  # 字段映射配置 - 支持多种字段名变体
  FIELD_MAPPINGS = {
    document_number: %w[报销单单号 单据编号 报销单号 发票号],
    fee_type: %w[费用类型 费用类型名称 费用名称],
    original_amount: %w[原始金额 金额 费用金额 报销金额],
    fee_date: %w[费用发生日期 发生日期 费用日期 日期],
    description: %w[费用说明 描述 备注 说明],
    fee_id: %w[费用id 费用ID 费用编号 ID]
  }.freeze

  def initialize(file, current_admin_user, options = {})
    super(file, current_admin_user)
    @skip_existing = options[:skip_existing] || false
    @batch_manager = BatchImportManager.new(FeeDetail, optimization_level: :moderate)
    @sqlite_optimizer = SqliteOptimizationManager.new(ActiveRecord::Base.connection, level: :moderate)
    @performance_stats = {}
  end

  def import(test_spreadsheet = nil)
    # 使用SQLite优化进行导入
    @sqlite_optimizer.during_import do
      # 使用基类的通用文件验证和解析
      parse_result = parse_file(test_spreadsheet)
      return parse_result unless parse_result[:success]

      sheet = parse_result[:sheet]
      headers = parse_result[:headers]

      # 预验证：检查必需字段
      validation_result = validate_required_fields(headers)
      return validation_result unless validation_result[:success]

      # 1. 解析所有数据到内存
      all_rows_data = parse_all_rows(sheet, headers)
      return format_result(errors: ['没有有效数据']) if all_rows_data.empty?

      # 2. 预加载关联数据以优化性能
      preload_associations(all_rows_data)

      # 3. 数据验证和预处理
      validated_data = validate_and_preprocess_data(all_rows_data)

      # 4. 批量处理（禁用回调以提升性能）
      disabled_callbacks = [
        %i[save after update_reimbursement_status]
      ]

      @batch_manager.batch_import_with_disabled_callbacks(validated_data, disabled_callbacks) do |batch|
        process_fee_detail_batch(batch)
      end

      # 5. 批量更新报销单状态
      batch_update_reimbursement_statuses(validated_data)

      # 6. 收集性能统计
      @performance_stats = @batch_manager.performance_stats

      format_result(
        created: @created_count,
        updated: @updated_count,
        skipped: @skipped_count,
        performance_stats: @performance_stats
      )
    end
  end

  private

  def validate_required_fields(headers)
    # 检查每个必需字段的映射是否至少有一个存在于headers中
    missing_field_types = []

    FIELD_MAPPINGS.each do |field_type, field_variants|
      # 只检查核心必需字段
      next unless [:document_number, :fee_type, :original_amount, :fee_date].include?(field_type)

      # 检查是否有任何变体存在于headers中
      has_field = field_variants.any? { |variant| headers.include?(variant) }
      missing_field_types << field_type unless has_field
    end

    if missing_field_types.any?
      missing_field_names = missing_field_types.map { |type|
        FIELD_MAPPINGS[type].join(' 或 ')
      }
      {
        success: false,
        errors: ["缺少必需字段: #{missing_field_names.join(', ')}"]
      }
    else
      { success: true }
    end
  end

  def parse_all_rows(sheet, headers)
    all_rows = []
    sheet.each_with_index do |row, idx|
      next if idx == 0 # Skip header row

      row_data = Hash[headers.zip(row)]
      all_rows << row_data if row_data.values.any?(&:present?)
    end
    all_rows
  end

  def preload_associations(rows_data)
    # 预加载所有相关的报销单以避免N+1查询
    document_numbers = rows_data.map { |row| extract_field_value(row, :document_number) }.compact.uniq
    @reimbursements_cache = Reimbursement.where(invoice_number: document_numbers).index_by(&:invoice_number)

    # 预加载费用类型
    fee_type_names = rows_data.map { |row| extract_field_value(row, :fee_type) }.compact.uniq
    @fee_types_cache = FeeType.where(name: fee_type_names).index_by(&:name)
  end

  def validate_and_preprocess_data(rows_data)
    validated_data = []

    rows_data.each_with_index do |row_data, index|
      row_number = index + 2 # +2 because we skip header and index starts from 0

      begin
        processed_data = process_row_data(row_data, row_number)
        validated_data << processed_data if processed_data
      rescue => e
        handle_error(e, message: "处理第#{row_number}行数据时出错", reraise: false)
      end
    end

    validated_data
  end

  def process_row_data(row_data, row_number)
    # 提取基础字段
    document_number = extract_field_value(row_data, :document_number)
    fee_type_name = extract_field_value(row_data, :fee_type)
    original_amount = extract_field_value(row_data, :original_amount)
    fee_date_str = extract_field_value(row_data, :fee_date)

    # 验证必需字段
    raise ArgumentError, "缺少报销单单号" if document_number.blank?
    raise ArgumentError, "缺少费用类型" if fee_type_name.blank?
    raise ArgumentError, "缺少原始金额" if original_amount.blank?
    raise ArgumentError, "缺少费用发生日期" if fee_date_str.blank?

    # 查找关联数据
    reimbursement = @reimbursements_cache[document_number]
    raise ArgumentError, "报销单不存在: #{document_number}" unless reimbursement

    fee_type = @fee_types_cache[fee_type_name]
    raise ArgumentError, "费用类型不存在: #{fee_type_name}" unless fee_type

    # 解析金额和日期
    amount = parse_amount(original_amount)
    fee_date = parse_date_field(fee_date_str)

    raise ArgumentError, "无效的金额格式: #{original_amount}" unless amount
    raise ArgumentError, "无效的日期格式: #{fee_date_str}" unless fee_date

    # 检查重复记录
    fee_id = extract_field_value(row_data, :fee_id)

    if @skip_existing && fee_id.present?
      existing_fee = FeeDetail.find_by(id: fee_id)
      if existing_fee
        @skipped_count += 1
        return nil
      end
    end

    {
      row_number: row_number,
      document_number: document_number,
      fee_type: fee_type,
      original_amount: amount,
      fee_date: fee_date,
      description: extract_field_value(row_data, :description),
      fee_id: fee_id,
      reimbursement: reimbursement,
      row_data: row_data
    }
  end

  def extract_field_value(row_data, field_type)
    field_names = FIELD_MAPPINGS[field_type] || []
    field_names.each do |field_name|
      value = row_data[field_name]
      return value.to_s.strip if value.present?
    end
    nil
  end

  def parse_amount(amount_str)
    return nil if amount_str.blank?

    # 移除常见的货币符号和格式字符
    cleaned_str = amount_str.to_s.gsub(/[￥¥$,，,]/, '').strip
    return nil if cleaned_str.blank?

    # 验证是否为有效数字格式
    return nil unless cleaned_str.match?(/\A-?\d+(\.\d+)?\z/)

    # 转换为浮点数
    cleaned_str.to_f
  rescue => e
    Rails.logger.warn "金额解析失败: #{amount_str} - #{e.message}"
    nil
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

  def process_fee_detail_batch(batch)
    fee_details_to_create = []
    fee_details_to_update = []

    batch.each do |data|
      fee_detail = build_fee_detail(data)

      if fee_detail.new_record?
        fee_details_to_create << fee_detail
      else
        fee_details_to_update << fee_detail
      end
    end

    # 批量创建
    if fee_details_to_create.any?
      attributes_list = fee_details_to_create.map do |fee_detail|
        fee_detail.attributes.except('id', 'created_at', 'updated_at')
      end
      created_count = FeeDetail.insert_all(attributes_list)
      @created_count += created_count.length
    end

    # 批量更新
    if fee_details_to_update.any?
      fee_details_to_update.each(&:save)
      @updated_count += fee_details_to_update.size
    end
  end

  def build_fee_detail(data)
    attributes = {
      document_number: data[:document_number],
      fee_type: data[:fee_type].name,
      amount: data[:original_amount],
      fee_date: data[:fee_date],
      notes: data[:description],
      verification_status: 'pending'
    }

    if data[:fee_id].present?
      fee_detail = FeeDetail.find_by(id: data[:fee_id])
      if fee_detail
        fee_detail.assign_attributes(attributes)
      else
        fee_detail = FeeDetail.new(attributes)
      end
    else
      fee_detail = FeeDetail.new(attributes)
    end

    fee_detail
  end

  def batch_update_reimbursement_statuses(validated_data)
    # 批量更新有关联费用明细的报销单状态
    affected_reimbursement_ids = validated_data
      .map { |data| data[:reimbursement]&.id }
      .compact
      .uniq

    if affected_reimbursement_ids.any?
      Reimbursement.where(id: affected_reimbursement_ids)
        .where(status: 'pending')
        .update_all(status: 'processing', updated_at: Time.current)
    end
  end

  def format_result(additional_data = {})
    {
      success: @errors.empty?,
      created: @created_count,
      updated: @updated_count,
      skipped: @skipped_count,
      errors: @error_count,
      error_details: @errors,
      unmatched_receipts: @unmatched_receipts,
      performance_stats: @performance_stats
    }.merge(additional_data)
  end
end