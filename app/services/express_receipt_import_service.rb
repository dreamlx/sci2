# app/services/express_receipt_import_service.rb
# DEPRECATED: 此服务已被 UnifiedExpressReceiptImportService 替代
# 计划废弃日期: 2025-11-30
# 迁移指南: 请使用 UnifiedExpressReceiptImportService
# 废弃原因: 功能重复，统一架构维护
#
# ⚠️  重要提醒:
# - 此服务将在未来版本中完全移除
# - 新项目请直接使用 UnifiedExpressReceiptImportService
# - 现有调用请尽快迁移到统一版本
# - 如有迁移问题，请查看 development plan 文档
#
class ExpressReceiptImportService
  TRACKING_NUMBER_REGEX = /快递单号[：:]\s*(\w+)/i # 提取快递单号的正则表达式

  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @created_count = 0
    @skipped_count = 0 # 用于重复记录
    @error_count = 0
    @errors = []
    @unmatched_receipts = []
    Current.admin_user = current_admin_user # 设置 Current.admin_user 用于回调
  end

  def import(test_spreadsheet = nil)
    return { success: false, errors: ['文件不存在'] } unless @file.present?
    return { success: false, errors: ['导入用户不存在'] } unless @current_admin_user

    begin
      file_path = if @file.respond_to?(:tempfile)
                    @file.tempfile.to_path.to_s
                  else
                    @file.path
                  end

      # 根据文件扩展名确定文件类型
      extension = File.extname(file_path).downcase[1..-1]
      return { success: false, errors: ['不支持的文件格式，请上传 CSV 或 Excel 文件'] } unless %w[csv xls xlsx].include?(extension)

      spreadsheet = test_spreadsheet || Roo::Spreadsheet.open(file_path, extension: extension.to_sym)

      # Handle both Excel and CSV files
      sheet = if spreadsheet.respond_to?(:sheet)
                spreadsheet.sheet(0)
              else
                spreadsheet # Directly use spreadsheet if it's a CSV
              end

      headers = sheet.row(1).map { |h| h.to_s.strip }
      Rails.logger.info "CSV Headers: #{headers.inspect}"

      sheet.each_with_index do |row, idx|
        next if idx == 0

        row_data = Hash[headers.zip(row)]
        Rails.logger.info "Row #{idx + 1} data: #{row_data.inspect}"
        import_express_receipt(row_data, idx + 1)
      end

      {
        success: true,
        created: @created_count,
        skipped: @skipped_count,
        unmatched: @unmatched_receipts.count,
        errors: @error_count,
        error_details: @errors,
        unmatched_details: @unmatched_receipts
      }
    rescue StandardError => e
      Rails.logger.error "Express Receipt Import Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, errors: ["导入过程中发生错误: #{e.message}"] }
    end
  end

  private

  def import_express_receipt(row, row_number)
    # 添加调试日志
    Rails.logger.debug "ExpressReceiptImportService: 行 #{row_number} 原始数据: #{row.inspect}"

    document_number = row['单据编号']&.strip || row['单号']&.strip # 兼容新旧列名
    operation_notes = row['操作意见']&.strip
    received_at_str = row['操作时间'] || row['操作日期'] # 兼容新旧列名
    filling_id = row['Filling ID']&.strip

    # 添加调试日志
    Rails.logger.debug "ExpressReceiptImportService: 行 #{row_number} 解析结果 - 单据编号: #{document_number.inspect}, 操作时间: #{received_at_str.inspect}, Filling ID: #{filling_id.inspect}"

    # 使用正则表达式提取快递单号
    tracking_number = operation_notes&.match(TRACKING_NUMBER_REGEX)&.captures&.first&.strip

    unless document_number.present? && tracking_number.present?
      @error_count += 1
      @errors << "行 #{row_number}: 无法找到有效的单号或从操作意见中提取快递单号"
      return
    end

    # 查找报销单
    reimbursement = Reimbursement.find_by(invoice_number: document_number)

    unless reimbursement
      @unmatched_receipts << { row: row_number, document_number: document_number, tracking_number: tracking_number,
                               error: '报销单不存在' }
      return
    end

    # 如果有 filling_id，则查找并更新现有记录
    if filling_id.present?
      work_order = ExpressReceiptWorkOrder.find_by(filling_id: filling_id)

      unless work_order
        @error_count += 1
        @errors << "行 #{row_number}: 找不到对应的填充ID记录 (Filling ID: #{filling_id})"
        return
      end

      received_at = parse_datetime(received_at_str)

      # 添加调试日志
      Rails.logger.debug "ExpressReceiptImportService: 行 #{row_number} 时间处理 (更新记录) - 原始时间字符串: #{received_at_str.inspect}, 解析后时间: #{parse_datetime(received_at_str).inspect}"

      # 严格的时间验证
      if received_at.nil?
        if received_at_str.present?
          Rails.logger.error "ExpressReceiptImportService: 行 #{row_number} 错误：时间解析失败！原始时间字符串: #{received_at_str.inspect}"
          @error_count += 1
          @errors << "行 #{row_number}: 无法解析操作时间 '#{received_at_str}'，请检查时间格式是否正确（支持格式：YYYY-MM-DD HH:MM:SS、YYYY/MM/DD HH:MM:SS等）"
          return
        else
          Rails.logger.error "ExpressReceiptImportService: 行 #{row_number} 错误：操作时间为空！"
          @error_count += 1
          @errors << "行 #{row_number}: 操作时间不能为空"
          return
        end
      end

      # 验证时间是否在合理范围内（不能是未来时间，不能太早）
      if received_at > Time.current + 1.day
        Rails.logger.warn "ExpressReceiptImportService: 行 #{row_number} 警告：操作时间 #{received_at} 是未来时间"
      elsif received_at < Time.current - 10.years
        Rails.logger.warn "ExpressReceiptImportService: 行 #{row_number} 警告：操作时间 #{received_at} 过于久远"
      end

      # 更新现有记录
      ActiveRecord::Base.transaction do
        if work_order.update(
          reimbursement: reimbursement,
          tracking_number: tracking_number,
          received_at: received_at,
          created_by: @current_admin_user.id
        )
          @created_count += 1
          # 更新报销单状态
          reimbursement.mark_as_received(received_at)

          # 重置通知状态
          if reimbursement.last_viewed_express_receipts_at.present?
            reimbursement.update_column(:last_viewed_express_receipts_at, nil)
            Rails.logger.debug "ExpressReceiptImportService: 重置报销单 ##{reimbursement.id} 的通知状态"
          end
        else
          @error_count += 1
          error_messages = work_order.errors.full_messages.join(', ')
          @errors << "行 #{row_number} (单号: #{document_number}, 快递: #{tracking_number}): #{error_messages}"
          Rails.logger.debug "WorkOrder Update Failed for Row #{row_number} (DN: #{document_number}, TN: #{tracking_number}): #{error_messages}"
          raise ActiveRecord::Rollback
        end
      end
    else
      # 如果没有 filling_id，按原有逻辑创建新记录
      # 重复检查（如果存在则跳过）
      if ExpressReceiptWorkOrder.exists?(reimbursement_id: reimbursement.id, tracking_number: tracking_number)
        @skipped_count += 1
        return
      end

      received_at = parse_datetime(received_at_str)

      # 添加调试日志
      Rails.logger.debug "ExpressReceiptImportService: 行 #{row_number} 时间处理 (创建新记录) - 原始时间字符串: #{received_at_str.inspect}, 解析后时间: #{parse_datetime(received_at_str).inspect}"

      # 严格的时间验证
      if received_at.nil?
        if received_at_str.present?
          Rails.logger.error "ExpressReceiptImportService: 行 #{row_number} 错误：时间解析失败！原始时间字符串: #{received_at_str.inspect}"
          @error_count += 1
          @errors << "行 #{row_number}: 无法解析操作时间 '#{received_at_str}'，请检查时间格式是否正确（支持格式：YYYY-MM-DD HH:MM:SS、YYYY/MM/DD HH:MM:SS等）"
          return
        else
          Rails.logger.error "ExpressReceiptImportService: 行 #{row_number} 错误：操作时间为空！"
          @error_count += 1
          @errors << "行 #{row_number}: 操作时间不能为空"
          return
        end
      end

      # 验证时间是否在合理范围内（不能是未来时间，不能太早）
      if received_at > Time.current + 1.day
        Rails.logger.warn "ExpressReceiptImportService: 行 #{row_number} 警告：操作时间 #{received_at} 是未来时间"
      elsif received_at < Time.current - 10.years
        Rails.logger.warn "ExpressReceiptImportService: 行 #{row_number} 警告：操作时间 #{received_at} 过于久远"
      end

      # 创建快递收单工单
      work_order = ExpressReceiptWorkOrder.new(
        reimbursement: reimbursement,
        status: 'completed', # Req 2
        tracking_number: tracking_number,
        received_at: received_at, # 使用 '操作时间'
        # courier_name: courier_name, # 源文件中不可用
        created_by: @current_admin_user.id # MODIFIED from creator_id
      )

      # 使用事务确保工单创建和报销单状态更新的原子性
      ActiveRecord::Base.transaction do
        if work_order.save
          @created_count += 1
          # 更新报销单状态
          reimbursement.mark_as_received(received_at) # 更新收单状态/日期

          # 重置通知状态，确保新的快递收单工单会触发通知
          # 如果last_viewed_express_receipts_at已设置，将其设为nil以触发通知
          if reimbursement.last_viewed_express_receipts_at.present?
            reimbursement.update_column(:last_viewed_express_receipts_at, nil)
            Rails.logger.debug "ExpressReceiptImportService: 重置报销单 ##{reimbursement.id} 的通知状态"
          end

          # 不再更新内部状态，根据新需求导入快递收单不改变报销单内部状态
        else
          @error_count += 1
          error_messages = work_order.errors.full_messages.join(', ')
          @errors << "行 #{row_number} (单号: #{document_number}, 快递: #{tracking_number}): #{error_messages}"
          Rails.logger.debug "WorkOrder Save Failed for Row #{row_number} (DN: #{document_number}, TN: #{tracking_number}): #{error_messages}"
          raise ActiveRecord::Rollback # 错误时回滚事务
        end
      end
    end
  rescue StateMachines::InvalidTransition => e
    # 处理报销单更新过程中可能出现的状态机错误
    @error_count += 1
    @errors << "行 #{row_number} (单号: #{document_number}): 更新报销单状态失败 - #{e.message}"
    # 工单可能已保存，考虑是否需要清理或只记录
    Rails.logger.error "Failed to update reimbursement status for WO on row #{row_number} (DN: #{document_number}): #{e.message}"
  end

  def parse_datetime(datetime_string)
    return nil unless datetime_string.present?

    # 如果已经是时间对象，直接返回
    if datetime_string.is_a?(Date) || datetime_string.is_a?(DateTime) || datetime_string.is_a?(Time)
      return datetime_string
    end

    datetime_str = datetime_string.to_s.strip
    return nil if datetime_str.blank?

    # 检查是否是Excel序列号格式（纯数字，可能包含小数点）
    # Excel序列号不应该被当作有效的时间格式处理
    if datetime_str.match?(/^\d+(\.\d+)?$/)
      Rails.logger.warn "ExpressReceiptImportService: 拒绝Excel序列号格式的时间字符串: '#{datetime_str}'"
      return nil
    end

    begin
      # 尝试标准解析
      DateTime.parse(datetime_str)
    rescue ArgumentError
      # 如果标准解析失败，尝试常见格式
      begin
        # 尝试常见的时间格式
        common_formats = [
          '%Y-%m-%d %H:%M:%S',    # 2025-01-01 10:00:00
          '%Y/%m/%d %H:%M:%S',    # 2025/01/01 10:00:00
          '%Y-%m-%d %H:%M',       # 2025-01-01 10:00
          '%Y/%m/%d %H:%M',       # 2025/01/01 10:00
          '%Y-%m-%d',             # 2025-01-01
          '%Y/%m/%d',             # 2025/01/01
          '%d/%m/%Y %H:%M:%S',    # 01/01/2025 10:00:00
          '%m/%d/%Y %H:%M:%S',    # 01/01/2025 10:00:00
          '%d-%m-%Y %H:%M:%S',    # 01-01-2025 10:00:00
          '%m-%d-%Y %H:%M:%S' # 01-01-2025 10:00:00
        ]

        common_formats.each do |format|
          parsed_time = DateTime.strptime(datetime_str, format)
          Rails.logger.debug "ExpressReceiptImportService: 成功解析时间 '#{datetime_str}' 使用格式 '#{format}' => #{parsed_time}"
          return parsed_time
        rescue ArgumentError
          # 继续尝试下一种格式
        end

        # 所有格式都尝试失败，记录警告
        Rails.logger.warn "ExpressReceiptImportService: 无法解析时间字符串: '#{datetime_str}'，尝试的格式: #{common_formats.inspect}"
        nil
      rescue StandardError => e
        Rails.logger.error "ExpressReceiptImportService: 时间解析异常: '#{datetime_str}' - #{e.message}"
        nil
      end
    end
  end
end