# SCI2 工单系统服务实现 (STI 版本 - v2)

## 1. 数据导入服务

### 1.1 报销单导入服务 (ReimbursementImportService)

*   Handles `is_electronic`, `external_status`, `approval_date`, `approver_name`.
*   Updates existing records based on `invoice_number` (Req 15).
*   Sets initial internal `status` based on `external_status`.

```ruby
# app/services/reimbursement_import_service.rb
class ReimbursementImportService
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
      spreadsheet = Roo::Spreadsheet.open(@file.path)
      sheet = spreadsheet.sheet(0) # Assuming the first sheet

      headers = sheet.row(1).map { |h| h.to_s.strip } # Normalize headers
      sheet.each_with_index do |row, idx|
        next if idx == 0 # Skip header row

        row_data = Hash[headers.zip(row)]
        import_reimbursement(row_data, idx + 1)
      end

      {
        success: true,
        created: @created_count,
        updated: @updated_count,
        errors: @error_count,
        error_details: @errors
      }
    rescue => e
      Rails.logger.error "Reimbursement Import Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, errors: ["导入过程中发生错误: #{e.message}"] }
    end
  end

  private

  def import_reimbursement(row, row_number)
    invoice_number = row['报销单单号']&.strip

    unless invoice_number.present?
      @error_count += 1
      @errors << "行 #{row_number}: 报销单单号不能为空"
      return
    end

    reimbursement = Reimbursement.find_or_initialize_by(invoice_number: invoice_number)
    is_new_record = reimbursement.new_record?

    # Map attributes from row data
    reimbursement.assign_attributes(
      document_name: row['单据名称'] || reimbursement.document_name,
      applicant: row['报销单申请人'] || reimbursement.applicant,
      applicant_id: row['报销单申请人工号'] || reimbursement.applicant_id,
      company: row['申请人公司'] || reimbursement.company,
      department: row['申请人部门'] || reimbursement.department,
      amount: row['报销金额（单据币种）'] || reimbursement.amount,
      receipt_status: parse_receipt_status(row['收单状态']) || reimbursement.receipt_status,
      receipt_date: parse_date(row['收单日期']) || reimbursement.receipt_date,
      submission_date: parse_date(row['提交报销日期']) || reimbursement.submission_date,
      is_electronic: row['单据标签']&.include?('全电子发票') || false, # Explicitly default to false
      external_status: row['报销单状态'] || reimbursement.external_status, # Store external status
      approval_date: parse_datetime(row['报销单审核通过日期']) || reimbursement.approval_date,
      approver_name: row['审核通过人'] || reimbursement.approver_name
      # Add other optional fields if needed
    )

    # Set internal status for new records based on external status
    if is_new_record
      # Check if external status indicates closure (adjust keywords if needed)
      if ['已付款', '已完成'].include?(reimbursement.external_status)
        reimbursement.status = 'closed'
      else
        reimbursement.status = 'pending'
      end
    end

    if reimbursement.save
      if is_new_record
        @created_count += 1
      elsif reimbursement.previously_changed?
        @updated_count += 1
      end
    else
      @error_count += 1
      @errors << "行 #{row_number} (单号: #{invoice_number}): #{reimbursement.errors.full_messages.join(', ')}"
    end
  end

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
```

### 1.2 快递收单导入服务 (ExpressReceiptImportService)

*   Creates `ExpressReceiptWorkOrder` (status `completed`, `created_by`).
*   Extracts `tracking_number` from `操作意见`.
*   Uses `操作时间` for `received_at`.
*   Adds duplicate check (`reimbursement_id` + `tracking_number`).
*   Updates `Reimbursement` status.

```ruby
# app/services/express_receipt_import_service.rb
class ExpressReceiptImportService
  TRACKING_NUMBER_REGEX = /快递单号[：:]\s*(\w+)/i # Regex to extract tracking number

  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @created_count = 0
    @skipped_count = 0 # For duplicates
    @error_count = 0
    @errors = []
    @unmatched_receipts = []
  end

  def import
    return { success: false, errors: ["文件不存在"] } unless @file.present?
    return { success: false, errors: ["导入用户不存在"] } unless @current_admin_user

    begin
      spreadsheet = Roo::Spreadsheet.open(@file.path)
      sheet = spreadsheet.sheet(0)

      headers = sheet.row(1).map { |h| h.to_s.strip }
      sheet.each_with_index do |row, idx|
        next if idx == 0

        row_data = Hash[headers.zip(row)]
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
    rescue => e
      Rails.logger.error "Express Receipt Import Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, errors: ["导入过程中发生错误: #{e.message}"] }
    end
  end

  private

  def import_express_receipt(row, row_number)
    document_number = row['单号']&.strip
    operation_notes = row['操作意见']&.strip
    received_at_str = row['操作时间'] # Use '操作时间'

    # Extract tracking number using regex
    tracking_number = operation_notes&.match(TRACKING_NUMBER_REGEX)&.captures&.first&.strip

    unless document_number.present? && tracking_number.present?
      @error_count += 1
      @errors << "行 #{row_number}: 无法找到有效的单号或从操作意见中提取快递单号"
      return
    end

    reimbursement = Reimbursement.find_by(invoice_number: document_number)

    unless reimbursement
      @unmatched_receipts << { row: row_number, document_number: document_number, tracking_number: tracking_number, error: "报销单不存在" }
      return
    end

    # Duplicate Check (Skip if exists)
    if ExpressReceiptWorkOrder.exists?(reimbursement_id: reimbursement.id, tracking_number: tracking_number)
       @skipped_count += 1
       return
    end

    received_at = parse_datetime(received_at_str) || Time.current

    work_order = ExpressReceiptWorkOrder.new(
      reimbursement: reimbursement,
      status: 'completed', # Req 2
      tracking_number: tracking_number,
      received_at: received_at, # Use '操作时间'
      # courier_name: courier_name, # Not available in source file
      created_by: @current_admin_user.id # Req 2
    )

    ActiveRecord::Base.transaction do
      if work_order.save
        @created_count += 1
        # Update reimbursement status
        reimbursement.mark_as_received(received_at) # Update receipt status/date
        reimbursement.start_processing! if reimbursement.pending? # Update internal status
      else
        @error_count += 1
        @errors << "行 #{row_number} (单号: #{document_number}, 快递: #{tracking_number}): #{work_order.errors.full_messages.join(', ')}"
        raise ActiveRecord::Rollback # Rollback transaction on error
      end
    end
  rescue StateMachines::InvalidTransition => e
      # Handle potential state machine errors during reimbursement update
      @error_count += 1
      @errors << "行 #{row_number} (单号: #{document_number}): 更新报销单状态失败 - #{e.message}"
      # work_order might have been saved, consider if cleanup is needed or just log
      Rails.logger.error "Failed to update reimbursement status for WO #{work_order.id}: #{e.message}"
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
```

### 1.3 费用明细导入服务 (FeeDetailImportService)

*   Adds duplicate check (`document_number` + `fee_type` + `amount` + `fee_date`).

```ruby
# app/services/fee_detail_import_service.rb
class FeeDetailImportService
  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @imported_count = 0
    @skipped_count = 0 # For duplicates
    @error_count = 0
    @errors = []
    @unmatched_details = []
  end

  def import
    return { success: false, errors: ["文件不存在"] } unless @file.present?

    begin
      spreadsheet = Roo::Spreadsheet.open(@file.path)
      sheet = spreadsheet.sheet(0)

      headers = sheet.row(1).map { |h| h.to_s.strip }
      sheet.each_with_index do |row, idx|
        next if idx == 0

        row_data = Hash[headers.zip(row)]
        import_fee_detail(row_data, idx + 1)
      end

      {
        success: true,
        imported: @imported_count,
        skipped: @skipped_count,
        unmatched: @unmatched_details.count,
        errors: @error_count,
        error_details: @errors,
        unmatched_details: @unmatched_details
      }
    rescue => e
      Rails.logger.error "Fee Detail Import Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, errors: ["导入过程中发生错误: #{e.message}"] }
    end
  end

  private

  def import_fee_detail(row, row_number)
    document_number = row['报销单单号']&.strip
    fee_type = row['费用类型']&.strip
    amount_str = row['原始金额']
    fee_date_str = row['费用发生日期']

    unless document_number.present? && fee_type.present? && amount_str.present? && fee_date_str.present?
      @error_count += 1
      @errors << "行 #{row_number}: 缺少必要字段 (报销单单号, 费用类型, 金额, 费用发生日期)"
      return
    end

    reimbursement = Reimbursement.find_by(invoice_number: document_number)

    unless reimbursement
      @unmatched_details << { row: row_number, document_number: document_number, error: "报销单不存在" }
      return
    end

    amount = parse_decimal(amount_str)
    fee_date = parse_date(fee_date_str)

    # Duplicate Check (Req 14)
    if fee_date && amount && FeeDetail.exists?(
        document_number: document_number,
        fee_type: fee_type,
        amount: amount,
        fee_date: fee_date
      )
      @skipped_count += 1
      return # Skip duplicate
    end

    fee_detail = FeeDetail.new(
      document_number: document_number,
      fee_type: fee_type,
      amount: amount,
      currency: row['原始币种'] || 'CNY',
      fee_date: fee_date,
      payment_method: row['弹性字段11'],
      verification_status: FeeDetail::VERIFICATION_STATUS_PENDING # Req 8
    )

    if fee_detail.save
      @imported_count += 1
    else
      @error_count += 1
      @errors << "行 #{row_number} (单号: #{document_number}): #{fee_detail.errors.full_messages.join(', ')}"
    end
  end

  def parse_date(date_string)
    return nil unless date_string.present?
    begin
      date_string.is_a?(Date) || date_string.is_a?(DateTime) ? date_string.to_date : Date.parse(date_string.to_s)
    rescue ArgumentError
      nil
    end
  end

  def parse_decimal(decimal_string)
    return nil unless decimal_string.present?
    begin
      BigDecimal(decimal_string.to_s.gsub(',', '')) # Handle potential commas
    rescue ArgumentError
      nil
    end
  end
```

### 1.4 操作历史导入服务 (OperationHistoryImportService)

*   Adds duplicate check (`document_number` + `operation_type` + `operation_time` + `operator`).
*   Refines logic to trigger `reimbursement.close!` based on `operation_type == '审批'` AND `notes == '审批通过'`.

```ruby
# app/services/operation_history_import_service.rb
class OperationHistoryImportService
  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @imported_count = 0
    @skipped_count = 0 # For duplicates
    @updated_reimbursement_count = 0
    @error_count = 0
    @errors = []
    @unmatched_histories = []
  end

  def import
    return { success: false, errors: ["文件不存在"] } unless @file.present?

    begin
      spreadsheet = Roo::Spreadsheet.open(@file.path)
      sheet = spreadsheet.sheet(0)

      headers = sheet.row(1).map { |h| h.to_s.strip }
      sheet.each_with_index do |row, idx|
        next if idx == 0

        row_data = Hash[headers.zip(row)]
        import_operation_history(row_data, idx + 1)
      end

      {
        success: true,
        imported: @imported_count,
        skipped: @skipped_count,
        updated_reimbursements: @updated_reimbursement_count,
        unmatched: @unmatched_histories.count,
        errors: @error_count,
        error_details: @errors,
        unmatched_histories: @unmatched_histories
      }
    rescue => e
      Rails.logger.error "Operation History Import Failed: #{e.message}\n#{e.backtrace.join("\n")}"
      { success: false, errors: ["导入过程中发生错误: #{e.message}"] }
    end
  end

  private

  def import_operation_history(row, row_number)
    document_number = row['单据编号']&.strip
    operation_type = row['操作类型']&.strip
    operation_time_str = row['操作日期']
    operator = row['操作人']&.strip
    notes = row['操作意见']&.strip

    unless document_number.present? && operation_type.present? && operation_time_str.present? && operator.present?
      @error_count += 1
      @errors << "行 #{row_number}: 缺少必要字段 (单据编号, 操作类型, 操作日期, 操作人)"
      return
    end

    reimbursement = Reimbursement.find_by(invoice_number: document_number)

    unless reimbursement
      @unmatched_histories << { row: row_number, document_number: document_number, error: "报销单不存在" }
      return
    end

    operation_time = parse_datetime(operation_time_str)

    # Duplicate Check (Req 14)
    if operation_time && OperationHistory.exists?(
        document_number: document_number,
        operation_type: operation_type,
        operation_time: operation_time,
        operator: operator
      )
      @skipped_count += 1
      return # Skip duplicate
    end

    operation_history = OperationHistory.new(
      document_number: document_number,
      operation_type: operation_type,
      operation_time: operation_time,
      operator: operator,
      notes: notes
    )

    if operation_history.save
      @imported_count += 1

      # Check if this history entry closes the reimbursement (Req 158)
      if operation_type == '审批' && notes == '审批通过' && !reimbursement.closed?
        begin
          reimbursement.close! # Use state machine event
          @updated_reimbursement_count += 1
        rescue StateMachines::InvalidTransition => e
          Rails.logger.warn "Could not close Reimbursement #{reimbursement.id} based on history ID #{operation_history.id}: #{e.message}"
        end
      end
    else
      @error_count += 1
      @errors << "行 #{row_number} (单号: #{document_number}): #{operation_history.errors.full_messages.join(', ')}"
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
```

## 2. 工单处理服务 (STI)

*   Add helper `assign_shared_attributes` to handle shared Req 6/7 fields.
*   Call helper in relevant service methods.

### 2.1 审核工单处理服务 (AuditWorkOrderService)

```ruby
# app/services/audit_work_order_service.rb
class AuditWorkOrderService
  def initialize(audit_work_order, current_admin_user)
    raise ArgumentError, "Expected AuditWorkOrder" unless audit_work_order.is_a?(AuditWorkOrder)
    @audit_work_order = audit_work_order
    @current_admin_user = current_admin_user
    Current.admin_user = current_admin_user
  end

  def start_processing(params = {})
    assign_shared_attributes(params) # Assign shared fields if passed
    @audit_work_order.start_processing!
    true
  rescue StateMachines::InvalidTransition => e
    @audit_work_order.errors.add(:base, "无法开始处理: #{e.message}")
    false
  end

  def approve(params = {})
    assign_shared_attributes(params) # Assign shared fields if passed
    @audit_work_order.audit_comment = params[:audit_comment] if params[:audit_comment].present?
    @audit_work_order.approve!
    true
  rescue StateMachines::InvalidTransition => e
    @audit_work_order.errors.add(:base, "无法批准: #{e.message}")
    false
  end

  def reject(params = {})
    assign_shared_attributes(params) # Assign shared fields if passed
    comment = params[:audit_comment]
    if comment.blank?
       @audit_work_order.errors.add(:audit_comment, "必须填写拒绝理由")
       return false
    end
    @audit_work_order.audit_comment = comment
    @audit_work_order.reject!
    true
  rescue StateMachines::InvalidTransition => e
    @audit_work_order.errors.add(:base, "无法拒绝: #{e.message}")
    false
  end

  def select_fee_details(fee_detail_ids)
    @audit_work_order.select_fee_details(fee_detail_ids)
  end

  def update_fee_detail_verification(fee_detail_id, verification_status, comment = nil)
    fee_detail = @audit_work_order.fee_details.find_by(id: fee_detail_id)
    unless fee_detail
      @audit_work_order.errors.add(:base, "未找到关联的费用明细 ##{fee_detail_id}")
      return false
    end
    verification_service = FeeDetailVerificationService.new(@current_admin_user)
    # Use bang method to raise error on failure if needed
    verification_service.update_verification_status(fee_detail, verification_status, comment)
  end

  private

  # Helper to assign shared form attributes from Req 6/7
  def assign_shared_attributes(params)
      # Use strong parameters if called directly from controller
      # permitted_params = params.permit(:problem_type, :problem_description, :remark, :processing_opinion)
      # For internal service calls, slice is okay
      shared_attrs = params.slice(:problem_type, :problem_description, :remark, :processing_opinion)
      @audit_work_order.assign_attributes(shared_attrs) if shared_attrs.present?
  end
end
```

### 2.2 沟通工单处理服务 (CommunicationWorkOrderService)

```ruby
# app/services/communication_work_order_service.rb
class CommunicationWorkOrderService
  def initialize(communication_work_order, current_admin_user)
    raise ArgumentError, "Expected CommunicationWorkOrder" unless communication_work_order.is_a?(CommunicationWorkOrder)
    @communication_work_order = communication_work_order
    @current_admin_user = current_admin_user
    Current.admin_user = current_admin_user
  end

  def start_processing(params = {})
    assign_shared_attributes(params) # Assign shared fields if passed
    @communication_work_order.start_processing!
    true
  rescue StateMachines::InvalidTransition => e
    @communication_work_order.errors.add(:base, "无法开始处理: #{e.message}")
    false
  end

  def mark_needs_communication(params = {})
    assign_shared_attributes(params) # Assign shared fields if passed
    @communication_work_order.mark_needs_communication!
    true
  rescue StateMachines::InvalidTransition => e
    @communication_work_order.errors.add(:base, "无法标记为需要沟通: #{e.message}")
    false
  end

  def approve(params = {})
    assign_shared_attributes(params) # Assign shared fields if passed
    @communication_work_order.resolution_summary = params[:resolution_summary] if params[:resolution_summary].present?
    @communication_work_order.approve!
    true
  rescue StateMachines::InvalidTransition => e
    @communication_work_order.errors.add(:base, "无法批准: #{e.message}")
    false
  end

  def reject(params = {})
    assign_shared_attributes(params) # Assign shared fields if passed
    summary = params[:resolution_summary]
     if summary.blank?
       @communication_work_order.errors.add(:resolution_summary, "必须填写拒绝理由/摘要")
       return false
    end
    @communication_work_order.resolution_summary = summary
    @communication_work_order.reject!
    true
  rescue StateMachines::InvalidTransition => e
    @communication_work_order.errors.add(:base, "无法拒绝: #{e.message}")
    false
  end

  def add_communication_record(params)
    record = @communication_work_order.add_communication_record(
      params.slice(:content, :communicator_role, :communicator_name, :communication_method).merge(
        communicator_name: params[:communicator_name] || @current_admin_user.email,
        recorded_at: Time.current
      )
    )
    unless record.persisted?
      @communication_work_order.errors.add(:base, "添加沟通记录失败: #{record.errors.full_messages.join(', ')}")
    end
    record
  end

  def select_fee_details(fee_detail_ids)
    @communication_work_order.select_fee_details(fee_detail_ids)
  end

  def update_fee_detail_verification(fee_detail_id, verification_status, comment = nil)
    fee_detail = @communication_work_order.fee_details.find_by(id: fee_detail_id)
     unless fee_detail
      @communication_work_order.errors.add(:base, "未找到关联的费用明细 ##{fee_detail_id}")
      return false
    end
    verification_service = FeeDetailVerificationService.new(@current_admin_user)
    verification_service.update_verification_status(fee_detail, verification_status, comment)
  end

  private

  # Helper to assign shared form attributes from Req 6/7
  def assign_shared_attributes(params)
      # Use strong parameters if called directly from controller
      # permitted_params = params.permit(:problem_type, :problem_description, :remark, :processing_opinion)
      shared_attrs = params.slice(:problem_type, :problem_description, :remark, :processing_opinion)
      @communication_work_order.assign_attributes(shared_attrs) if shared_attrs.present?
  end
end
```

### 2.3 快递收单工单处理服务 (ExpressReceiptWorkOrderService)

*(No changes needed)*

## 3. 费用明细验证服务

### 3.1 费用明细验证服务 (FeeDetailVerificationService)

*(No significant changes needed)*

## 4. 工单状态变更服务 (WorkOrderStatusChangeService)

*(Remains likely redundant)*

## 5. 服务注册 (ServiceRegistry)

*(No significant changes needed)*

## 6. 服务使用示例 (Controller/ActiveAdmin)

*   Update examples to show passing permitted params including shared fields.

```ruby
# Example in Admin::AuditWorkOrdersController or ActiveAdmin resource

def do_approve
  @work_order = AuditWorkOrder.find(params[:id])
  service = AuditWorkOrderService.new(@work_order, current_admin_user)
  # Permit and pass relevant params from form
  permitted_params = params.require(:audit_work_order).permit(
    :audit_comment, :problem_type, :problem_description, :remark, :processing_opinion
  )
  if service.approve(permitted_params)
    redirect_to admin_audit_work_order_path(@work_order), notice: "审核已通过"
  else
    @audit_work_order = @work_order # Reassign for form rendering
    flash.now[:alert] = "操作失败: #{@work_order.errors.full_messages.join(', ')}"
    render :approve # Render the form again
  end
end

def do_reject
  @work_order = AuditWorkOrder.find(params[:id])
  service = AuditWorkOrderService.new(@work_order, current_admin_user)
  # Permit and pass relevant params from form
  permitted_params = params.require(:audit_work_order).permit(
    :audit_comment, :problem_type, :problem_description, :remark, :processing_opinion
  )
  if service.reject(permitted_params)
    redirect_to admin_audit_work_order_path(@work_order), notice: "审核已拒绝"
  else
     @audit_work_order = @work_order # Reassign for form rendering
    flash.now[:alert] = "操作失败: #{@work_order.errors.full_messages.join(', ')}"
    render :reject # Render the form again
  end
end


# Example for creating CommunicationWorkOrder
def create_communication_work_order
  @reimbursement = Reimbursement.find(params[:reimbursement_id])

  # Build with permitted params, including shared fields
  @communication_work_order = @reimbursement.communication_work_orders.build(
     communication_creation_params.merge(created_by: current_admin_user.id)
  )

  # Use transaction to ensure atomicity of WO creation and fee detail selection
  ActiveRecord::Base.transaction do
    # Select Fee Details only if the WO is valid so far
    if @communication_work_order.valid? && params[:fee_detail_ids].present?
       @communication_work_order.select_fee_details(params[:fee_detail_ids])
    end

    if @communication_work_order.save
       # Add initial record if needed
       if params[:initial_content].present?
          comm_service = CommunicationWorkOrderService.new(@communication_work_order, current_admin_user)
          comm_service.add_communication_record(content: params[:initial_content], communicator_role: 'auditor', communication_method: 'system')
       end
       redirect_to admin_communication_work_order_path(@communication_work_order), notice: "沟通工单已创建"
    else
       # If save fails, render form and rollback transaction
       raise ActiveRecord::Rollback
    end
  end
rescue ActiveRecord::Rollback
  # Render form again if transaction rolled back (save failed)
  # Ensure instance variables needed by the form are set correctly
  flash.now[:alert] = "创建沟通工单失败: #{@communication_work_order.errors.full_messages.join(', ')}"
  render :new_communication_form # Assuming this view exists
end

private

def communication_creation_params
  # Permit shared fields on creation as well
  params.require(:communication_work_order).permit(
    :communication_method,
    :initiator_role,
    :problem_type, # Shared field
    :problem_description, # Shared field
    :remark, # Shared field
    :processing_opinion # Shared field
    # resolution_summary likely not set on creation
  )
end
```
end