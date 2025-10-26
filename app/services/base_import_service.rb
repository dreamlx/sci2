# app/services/base_import_service.rb
# 基础导入服务类，消除所有导入服务的重复代码
class BaseImportService
  # 通用文件格式支持
  SUPPORTED_EXTENSIONS = %w[csv xls xlsx].freeze

  # 通用状态跟踪
  attr_reader :created_count, :skipped_count, :error_count, :errors, :file, :current_admin_user

  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @created_count = 0
    @skipped_count = 0
    @error_count = 0
    @errors = []
    @unmatched_receipts = []
    Current.admin_user = current_admin_user
  end

  # 主导入方法 - 子类必须实现
  def import(test_spreadsheet = nil)
    raise NotImplementedError, "子类必须实现 import 方法"
  end

  protected

  # 通用文件验证逻辑
  def validate_file
    return { success: false, errors: ['文件不存在'] } unless @file.present?
    return { success: false, errors: ['导入用户不存在'] } unless @current_admin_user
    { success: true }
  end

  # 通用文件解析逻辑
  def parse_file(test_spreadsheet = nil)
    return { success: false, errors: ['文件不存在'] } unless validate_file[:success]

    begin
      file_path = extract_file_path
      extension = extract_file_extension(file_path)

      return { success: false, errors: ['不支持的文件格式，请上传 CSV 或 Excel 文件'] } unless supported_extension?(extension)

      spreadsheet = test_spreadsheet || Roo::Spreadsheet.open(file_path, extension: extension.to_sym)
      sheet = extract_sheet(spreadsheet)
      headers = extract_headers(sheet)

      { success: true, sheet: sheet, headers: headers }
    rescue => e
      { success: false, errors: ["文件解析失败: #{e.message}"] }
    end
  end

  # 通用行处理循环
  def process_rows(sheet, headers, &block)
    sheet.each_with_index do |row, idx|
      next if idx == 0  # 跳过标题行

      row_data = Hash[headers.zip(row)]
      Rails.logger.info "Row #{idx + 1} data: #{row_data.inspect}"
      yield row_data, idx + 1
    end
  end

  # 通用错误处理
  def handle_error(error, context = {})
    error_message = "#{context[:message]}: #{error.message}"
    @errors << error_message
    @error_count += 1
    Rails.logger.error error_message

    if context[:reraise]
      raise error
    end
  end

  # 通用结果格式化
  def format_result(additional_data = {})
    {
      success: @error_count == 0,
      created: @created_count,
      updated: 0,
      errors: @error_count,
      error_details: @errors,
      skipped: @skipped_count,
      **additional_data
    }
  end

  private

  def extract_file_path
    if @file.respond_to?(:tempfile) && @file.tempfile
      @file.tempfile.to_path.to_s
    else
      @file.path
    end
  end

  def extract_file_extension(file_path)
    File.extname(file_path).downcase[1..-1]
  end

  def supported_extension?(extension)
    SUPPORTED_EXTENSIONS.include?(extension)
  end

  def extract_sheet(spreadsheet)
    if spreadsheet.respond_to?(:sheet)
      spreadsheet.sheet(0)
    else
      spreadsheet
    end
  end

  def extract_headers(sheet)
    sheet.row(1).map { |h| h.to_s.strip }
  end

  # 子类可以重写的方法
  def validate_row_data(row_data, row_number)
    # 子类可以实现具体的行验证逻辑
    true
  end

  def process_valid_row(row_data, row_number)
    # 子类必须实现具体的行处理逻辑
    raise NotImplementedError, "子类必须实现 process_valid_row 方法"
  end
end