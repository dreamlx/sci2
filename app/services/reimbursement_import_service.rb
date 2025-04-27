class ReimbursementImportService
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
        import_reimbursement(row, i)
      end

      {
        success: true,
        created: @created_count,
        updated: @updated_count,
        errors: @error_count,
        error_details: @errors
      }
    rescue => e
      Rails.logger.error "报销单导入错误: #{e.message}\n#{e.backtrace.join("\n")}"
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

  def import_reimbursement(row, row_number)
    # 获取报销单号
    invoice_number = row[:报销单单号] || row[:invoice_number]

    # 检查必要字段
    unless invoice_number.present?
      @error_count += 1
      @errors << "行 #{row_number}: 报销单单号不能为空"
      return
    end

    # 查找或创建报销单
    reimbursement = Reimbursement.find_by(invoice_number: invoice_number)

    if reimbursement
      # 更新现有报销单
      update_reimbursement(reimbursement, row, row_number)
    else
      # 创建新报销单
      create_reimbursement(row, row_number)
    end
  end

  def create_reimbursement(row, row_number)
    attributes = {
      invoice_number: row[:报销单单号] || row[:invoice_number],
      document_name: row[:单据名称] || row[:document_name],
      applicant: row[:报销单申请人] || row[:applicant],
      applicant_id: row[:报销单申请人工号] || row[:applicant_id],
      company: row[:申请人公司] || row[:company],
      department: row[:申请人部门] || row[:department],
      amount: row[:报销金额] || row[:amount],
      receipt_status: parse_receipt_status(row[:收单状态] || row[:receipt_status]),
      reimbursement_status: parse_reimbursement_status(row[:报销单状态] || row[:reimbursement_status]),
      receipt_date: parse_date(row[:收单日期] || row[:receipt_date]),
      submission_date: parse_date(row[:提交报销日期] || row[:submission_date]),
      is_electronic: parse_is_electronic(row[:单据标签] || row[:document_tag]),
      is_complete: parse_is_complete(row[:报销单状态] || row[:reimbursement_status])
    }

    reimbursement = Reimbursement.new(attributes)

    if reimbursement.save
      @created_count += 1

      # 根据是否为电子发票决定是否创建审核工单
      create_audit_work_order_if_needed(reimbursement)
    else
      @error_count += 1
      @errors << "行 #{row_number}: #{reimbursement.errors.full_messages.join(', ')}"
    end
  end

  def update_reimbursement(reimbursement, row, row_number)
    attributes = {}
    attributes[:document_name] = row[:单据名称] || row[:document_name] if row[:单据名称].present? || row[:document_name].present?
    attributes[:applicant] = row[:报销单申请人] || row[:applicant] if row[:报销单申请人].present? || row[:applicant].present?
    attributes[:applicant_id] = row[:报销单申请人工号] || row[:applicant_id] if row[:报销单申请人工号].present? || row[:applicant_id].present?
    attributes[:company] = row[:申请人公司] || row[:company] if row[:申请人公司].present? || row[:company].present?
    attributes[:department] = row[:申请人部门] || row[:department] if row[:申请人部门].present? || row[:department].present?
    attributes[:amount] = row[:报销金额] || row[:amount] if row[:报销金额].present? || row[:amount].present?

    receipt_status = parse_receipt_status(row[:收单状态] || row[:receipt_status])
    attributes[:receipt_status] = receipt_status if receipt_status.present?

    reimbursement_status = parse_reimbursement_status(row[:报销单状态] || row[:reimbursement_status])
    attributes[:reimbursement_status] = reimbursement_status if reimbursement_status.present?

    receipt_date = parse_date(row[:收单日期] || row[:receipt_date])
    attributes[:receipt_date] = receipt_date if receipt_date.present?

    submission_date = parse_date(row[:提交报销日期] || row[:submission_date])
    attributes[:submission_date] = submission_date if submission_date.present?

    is_electronic = parse_is_electronic(row[:单据标签] || row[:document_tag])
    attributes[:is_electronic] = is_electronic unless is_electronic.nil?

    is_complete = parse_is_complete(row[:报销单状态] || row[:reimbursement_status])
    attributes[:is_complete] = is_complete unless is_complete.nil?

    if attributes.present? && reimbursement.update(attributes)
      @updated_count += 1

      # 检查是否需要创建审核工单
      create_audit_work_order_if_needed(reimbursement)
    elsif attributes.present?
      @error_count += 1
      @errors << "行 #{row_number}: 更新失败 - #{reimbursement.errors.full_messages.join(', ')}"
    end
  end

  def create_audit_work_order_if_needed(reimbursement)
    unless AuditWorkOrder.exists?(reimbursement_id: reimbursement.id, express_receipt_work_order_id: nil)
      AuditWorkOrder.create(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: @current_admin_user.id
      )
    end
  end

  def parse_receipt_status(status)
    return nil unless status.present?

    status = status.to_s.downcase
    if status.include?('已收单') || status == 'received'
      'received'
    else
      'pending'
    end
  end

  def parse_reimbursement_status(status)
    return nil unless status.present?

    status = status.to_s.downcase
    if status.include?('已付款') || status.include?('已完成') || status == 'closed'
      'closed'
    else
      'processing'
    end
  end

  def parse_date(date_string)
    return nil unless date_string.present?

    begin
      if date_string.is_a?(String)
        Date.parse(date_string)
      else
        date_string # 可能已经是日期对象
      end
    rescue ArgumentError
      nil
    end
  end

  def parse_is_electronic(tag)
    return nil unless tag.present?

    tag = tag.to_s.downcase
    tag.include?('全电子') || tag.include?('electronic')
  end

  def parse_is_complete(status)
    return nil unless status.present?

    status = status.to_s.downcase
    status.include?('已付款') || status.include?('已完成') || status == 'closed'
  end
end