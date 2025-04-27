class FeeDetailImportService
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

      # 将头部转换为符号形式，方便后续使用
      header_symbols = header.map { |h| h.to_s.strip.gsub(/\s+/, '_').downcase.to_sym }

      (2..spreadsheet.last_row).each do |i|
        row = Hash[[header_symbols, spreadsheet.row(i)].transpose]
        import_fee_detail(row, i)
      end

      {
        success: true,
        created: @created_count,
        updated: @updated_count,
        errors: @error_count,
        error_details: @errors
      }
    rescue => e
      Rails.logger.error "费用明细导入错误: #{e.message}\n#{e.backtrace.join("\n")}"
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

  def import_fee_detail(row, row_number)
    # 获取费用明细编号
    detail_number = row[:费用明细编号] || row[:detail_number]

    # 检查必要字段
    unless detail_number.present?
      @error_count += 1
      @errors << "行 #{row_number}: 费用明细编号不能为空"
      return
    end

    # 查找对应的审核工单
    audit_work_order = AuditWorkOrder.find_by(invoice_number: row[:报销单单号] || row[:invoice_number])

    unless audit_work_order
      @error_count += 1
      @errors << "行 #{row_number}: 对应的审核工单不存在"
      return
    end

    # 查找或创建费用明细记录
    fee_detail = FeeDetail.find_by(detail_number: detail_number)

    if fee_detail
      update_fee_detail(fee_detail, row, row_number)
    else
      create_fee_detail(row, audit_work_order, row_number)
    end
  end

  def create_fee_detail(row, audit_work_order, row_number)
    attributes = {
      detail_number: row[:费用明细编号] || row[:detail_number],
      description: row[:费用描述] || row[:description],
      amount: row[:金额] || row[:amount],
      status: parse_status(row[:状态] || row[:status]),
      audit_work_order_id: audit_work_order.id
    }

    fee_detail = FeeDetail.new(attributes)

    if fee_detail.save
      @created_count += 1
    else
      @error_count += 1
      @errors << "行 #{row_number}: #{fee_detail.errors.full_messages.join(', ')}"
    end
  end

  def update_fee_detail(fee_detail, row, row_number)
    attributes = {}
    attributes[:description] = row[:费用描述] || row[:description] if row[:费用描述].present? || row[:description].present?
    attributes[:amount] = row[:金额] || row[:amount] if row[:金额].present? || row[:amount].present?
    attributes[:status] = parse_status(row[:状态] || row[:status]) if row[:状态].present? || row[:status].present?

    if attributes.present? && fee_detail.update(attributes)
      @updated_count += 1
    elsif attributes.present?
      @error_count += 1
      @errors << "行 #{row_number}: 更新失败 - #{fee_detail.errors.full_messages.join(', ')}"
    end
  end

  def parse_status(status)
    return nil unless status.present?

    status = status.to_s.downcase
    if status.include?('已审核') || status == 'approved'
      'approved'
    elsif status.include?('待审核') || status == 'pending'
      'pending'
    elsif status.include?('拒绝') || status == 'rejected'
      'rejected'
    else
      'unknown'
    end
  end
end