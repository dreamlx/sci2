class ExpressReceiptImportService
  attr_reader :matched_count, :unmatched_count, :error_count, :errors

  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @matched_count = 0
    @unmatched_count = 0
    @error_count = 0
    @errors = []
    @unmatched_receipts = []
  end

  def import
    if @file.nil? || !File.exist?(@file)
      raise '文件不存在'
    end

    begin
      spreadsheet = open_spreadsheet
    rescue IOError => e
      return { success: false, errors: ['文件不存在'] }
    rescue RuntimeError => e
      return { success: false, errors: [e.message] }
    end

    header = spreadsheet.row(1)
    header_symbols = header.map { |h| h.to_s.strip.gsub(/\s+/, '_').downcase.to_sym }

    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header_symbols, spreadsheet.row(i)].transpose]
      import_express_receipt(row, i)
    end

    {
      success: true,
      matched: @matched_count,
      unmatched: @unmatched_count,
      errors: @error_count,
      error_details: @errors
    }
  rescue StandardError => e
    { success: false, errors: [e.message] }
  end

  private

  def open_spreadsheet
    case File.extname(@file.to_s)
    when '.csv'
      Roo::CSV.new(@file, csv_options: { encoding: 'utf-8' })
    when '.xls'
      Roo::Excel.new(@file)
    when '.xlsx'
      Roo::Excelx.new(@file)
    else
      raise '未知的文件类型'
    end
  end

  def import_express_receipt(row, row_number)
    # Implement import logic here
    # For example, increment counters, handle matched/unmatched, and record errors
  end

  def manual_match(tracking_number, reimbursement_id)
    unmatched_data = @unmatched_receipts.find { |r| r[:tracking_number] == tracking_number }
    reimbursement = Reimbursement.find_by(id: reimbursement_id)

    unless unmatched_data && reimbursement
      return { success: false, errors: ['无法找到未匹配的快递收单记录或报销单'] }
    end

    # Implement matching logic here
  end
end