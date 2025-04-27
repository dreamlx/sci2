class OperationHistoryImportService
  attr_reader :created_count, :updated_count, :error_count, :errors

  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @created_count = 0
    @updated_count = 0
    @error_count = 0
    @errors = []
  end

  def import
    return { success: false, errors: ["文件不存在"] } unless @file.present?

    begin
      spreadsheet = open_spreadsheet
      header = spreadsheet.row(1)

      # Convert header to symbols for easier access
      header_symbols = header.map { |h| h.to_s.strip.gsub(/\s+/, '_').downcase.to_sym }

      (2..spreadsheet.last_row).each do |i|
        row = Hash[[header_symbols, spreadsheet.row(i)].transpose]
        import_operation_history(row, i)
      end

      {
        success: true,
        created: @created_count,
        updated: @updated_count,
        errors: @error_count,
        error_details: @errors
      }
    rescue => e
      Rails.logger.error "操作历史导入错误: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, errors: [e.message] }
    end
  end

  private

  def open_spreadsheet
    case File.extname(@file.original_filename)
    when '.csv'
      Roo::CSV.new(@file.path, csv_options: {encoding: 'utf-8'})
    when '.xls'
      Roo::Excel.new(@file.path)
    when '.xlsx'
      Roo::Excelx.new(@file.path)
    else
      raise "未知的文件类型: #{@file.original_filename}"
    end
  end

  def import_operation_history(row, row_number)
    # 获取操作历史编号
    history_number = row[:操作历史编号] || row[:operation_history_number]

    # 检查必要字段
    unless history_number.present?
      @error_count += 1
      @errors << "行 #{row_number}: 操作历史编号不能为空"
      return
    end

    # 查找对应的工单
    work_order = WorkOrder.find_by(order_number: row[:工单编号] || row[:work_order_number])

    unless work_order
      @error_count += 1
      @errors << "行 #{row_number}: 对应的工单不存在"
      return
    end

    # 查找或创建操作历史记录
    operation_history = OperationHistory.find_by(history_number: history_number, work_order_id: work_order.id)

    if operation_history
      update_operation_history(operation_history, row, row_number)
    else
      create_operation_history(row, work_order, row_number)
    end
  end

  def create_operation_history(row, work_order, row_number)
    attributes = {
      history_number: row[:操作历史编号] || row[:operation_history_number],
      operation_type: parse_operation_type(row[:操作类型] || row[:operation_type]),
      operation_date: parse_date(row[:操作时间] || row[:operation_time]),
      operator: row[:操作人] || row[:operator] || @current_admin_user.email,
      remarks: row[:备注] || row[:remarks],
      work_order_id: work_order.id
    }

    operation_history = OperationHistory.new(attributes)

    if operation_history.save
      @created_count += 1
    else
      @error_count += 1
      @errors << "行 #{row_number}: #{operation_history.errors.full_messages.join(', ')}"
    end
  end

  def update_operation_history(operation_history, row, row_number)
    attributes = {}
    attributes[:operation_type] = parse_operation_type(row[:操作类型] || row[:operation_type]) if row[:操作类型].present? || row[:operation_type].present?
    attributes[:operation_date] = parse_date(row[:操作时间] || row[:operation_time]) if row[:操作时间].present? || row[:operation_time].present?
    attributes[:operator] = row[:操作人] || row[:operator] if row[:操作人].present? || row[:operator].present?
    attributes[:remarks] = row[:备注] || row[:remarks] if row[:备注].present? || row[:remarks].present?

    if attributes.present? && operation_history.update(attributes)
      @updated_count += 1
    elsif attributes.present?
      @error_count += 1
      @errors << "行 #{row_number}: 更新失败 - #{operation_history.errors.full_messages.join(', ')}"
    end
  end

  def parse_operation_type(operation_type)
    return nil unless operation_type.present?

    operation_type = operation_type.to_s.downcase
    case operation_type
    when '提交', 'submit'
      'submit'
    when '审核', 'audit'
      'audit'
    when '沟通', 'communication'
      'communication'
    when '完成', 'complete'
      'complete'
    else
      'unknown'
    end
  end

  def parse_date(date_string)
    return nil unless date_string.present?

    begin
      if date_string.is_a?(String)
        DateTime.parse(date_string)
      else
        date_string # Assume it's already a date object
      end
    rescue ArgumentError
      nil
    end
  end
end