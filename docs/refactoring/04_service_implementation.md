# SCI2 工单系统服务实现

## 1. 数据导入服务

### 1.1 报销单导入服务 (ReimbursementImportService)

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

      # Assuming the first row is headers
      headers = sheet.row(1)
      sheet.each_row_as_hash(headers: true, offset: 1) do |row|
        import_reimbursement(row)
      end

      {
        success: true,
        created: @created_count,
        updated: @updated_count,
        errors: @error_count,
        error_details: @errors
      }
    rescue => e
      { success: false, errors: [e.message] }
    end
  end

  private

  def import_reimbursement(row)
    invoice_number = row['报销单单号']

    # 检查必要字段
    unless invoice_number.present?
      @error_count += 1
      @errors << "行 #{$.}: 报销单单号不能为空"
      return
    end

    # 查找或创建报销单
    reimbursement = Reimbursement.find_by(invoice_number: invoice_number)

    if reimbursement
      # 更新现有报销单
      update_reimbursement(reimbursement, row)
    else
      # 创建新报销单
      create_reimbursement(row)
    end
  end

  def create_reimbursement(row)
    reimbursement = Reimbursement.new(
      invoice_number: row['报销单单号'],
      document_name: row['单据名称'],
      applicant: row['报销单申请人'],
      applicant_id: row['报销单申请人工号'],
      company: row['申请人公司'],
      department: row['申请人部门'],
      amount: row['报销金额（单据币种）'],
      receipt_status: parse_receipt_status(row['收单状态']),
      reimbursement_status: parse_reimbursement_status(row['报销单状态']),
      receipt_date: parse_date(row['收单日期']),
      submission_date: parse_date(row['提交报销日期']),
      is_electronic: row['单据标签']&.include?('全电子发票'),
      is_complete: parse_reimbursement_status(row['报销单状态']) == 'closed'
    )

    if reimbursement.save
      @created_count += 1

      # 如果是非电子发票，创建审核工单 (根据07_refactoring_adjustments调整，无论是否收单都创建)
      if !reimbursement.is_electronic
        create_audit_work_order(reimbursement)
      end
    else
      @error_count += 1
      @errors << "行 #{$.}: #{reimbursement.errors.full_messages.join(', ')}"
    end
  end

  def update_reimbursement(reimbursement, row)
    # 更新报销单属性
    reimbursement.assign_attributes(
      document_name: row['单据名称'] || reimbursement.document_name,
      applicant: row['报销单申请人'] || reimbursement.applicant,
      applicant_id: row['报销单申请人工号'] || reimbursement.applicant_id,
      company: row['申请人公司'] || reimbursement.company,
      department: row['申请人部门'] || reimbursement.department,
      amount: row['报销金额（单据币种）'] || reimbursement.amount,
      receipt_status: parse_receipt_status(row['收单状态']) || reimbursement.receipt_status,
      reimbursement_status: parse_reimbursement_status(row['报销单状态']) || reimbursement.reimbursement_status,
      receipt_date: parse_date(row['收单日期']) || reimbursement.receipt_date,
      submission_date: parse_date(row['提交报销日期']) || reimbursement.submission_date,
      is_electronic: row['单据标签']&.include?('全电子发票') || reimbursement.is_electronic,
      is_complete: parse_reimbursement_status(row['报销单状态']) == 'closed' || reimbursement.is_complete
    )

    if reimbursement.changed? && reimbursement.save
      @updated_count += 1
    end
  end

  def create_audit_work_order(reimbursement)
    # 确保不重复创建
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
    status.include?('已收单') ? 'received' : 'pending'
  end

  def parse_reimbursement_status(status)
    return nil unless status.present?
    status.include?('已付款') || status.include?('已完成') ? 'closed' : 'processing'
  end

  def parse_date(date_string)
    return nil unless date_string.present?
    begin
      DateTime.parse(date_string)
    rescue
      nil
    end
  end
end
```

### 1.2 快递收单导入服务 (ExpressReceiptImportService)

```ruby
# app/services/express_receipt_import_service.rb
class ExpressReceiptImportService
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
    return { success: false, errors: ["文件不存在"] } unless @file.present?

    begin
      spreadsheet = Roo::Spreadsheet.open(@file.path)
      sheet = spreadsheet.sheet(0) # Assuming the first sheet

      # Assuming the first row is headers
      headers = sheet.row(1)
      sheet.each_row_as_hash(headers: true, offset: 1) do |row|
        import_express_receipt(row)
      end

      {
        success: true,
        matched: @matched_count,
        unmatched: @unmatched_count,
        errors: @error_count,
        error_details: @errors,
        unmatched_receipts: @unmatched_receipts
      }
    rescue => e
      { success: false, errors: [e.message] }
    end
  end

  def manual_match(express_receipt_id, reimbursement_id)
    # 注意：manual_match 逻辑可能需要根据实际 ExpressReceipt 模型调整
    # 以下为示例逻辑
    # express_receipt = ExpressReceipt.find(express_receipt_id)
    reimbursement = Reimbursement.find(reimbursement_id)
    unmatched_data = @unmatched_receipts.find { |r| r[:tracking_number] == express_receipt_id } # 假设用 tracking_number 作为临时 ID

    if unmatched_data && reimbursement
      # 创建快递收单记录
      express_receipt = ExpressReceipt.create!(
        document_number: reimbursement.invoice_number,
        tracking_number: unmatched_data[:tracking_number],
        receive_date: parse_date(unmatched_data[:original_data]['操作时间']),
        receiver: unmatched_data[:original_data]['操作人'] || @current_admin_user.email,
        courier_company: extract_courier_company(unmatched_data[:original_data])
      )
      # 更新报销单收单状态
      reimbursement.mark_as_received(express_receipt.receive_date)
      # 创建工单
      create_express_receipt_work_order(express_receipt, reimbursement)
      return { success: true }
    else
      return { success: false, errors: ["无法匹配记录"] }
    end
  end

  private

  def import_express_receipt(row)
    document_number = extract_document_number(row)
    tracking_number = extract_tracking_number(row)

    # 检查必要字段
    unless document_number.present? && tracking_number.present?
      @error_count += 1
      @errors << "行 #{$.}: 单据号或快递单号不能为空"
      return
    end

    # 查找对应的报销单
    reimbursement = Reimbursement.find_by(invoice_number: document_number)

    unless reimbursement
      # 记录未匹配的快递单
      @unmatched_count += 1
      @unmatched_receipts << {
        original_data: row.to_h,
        document_number: document_number,
        tracking_number: tracking_number, # 使用 tracking_number 作为临时 ID
        error: "报销单不存在"
      }
      return # 报销单不存在，跳过此行
    end

    # 创建快递收单记录并关联到报销单
    # 注意：假设 ExpressReceipt 模型存在，如果不存在需要创建或调整
    express_receipt = ExpressReceipt.create!(
      document_number: document_number,
      tracking_number: tracking_number,
      receive_date: parse_date(row['操作时间']),
      receiver: row['操作人'] || @current_admin_user.email,
      courier_company: extract_courier_company(row)
    )

    # 更新报销单收单状态
    reimbursement.mark_as_received(express_receipt.receive_date)

    # 创建工单
    create_express_receipt_work_order(express_receipt, reimbursement)

    @matched_count += 1
  end

  def create_express_receipt_work_order(express_receipt, reimbursement)
    # 确保不重复创建
    unless ExpressReceiptWorkOrder.exists?(reimbursement_id: reimbursement.id, tracking_number: express_receipt.tracking_number)
      ExpressReceiptWorkOrder.create!(
        reimbursement: reimbursement,
        status: 'received',
        tracking_number: express_receipt.tracking_number,
        received_at: express_receipt.receive_date,
        courier_name: express_receipt.courier_company,
        created_by: @current_admin_user.id
      )
    end
  end

  def extract_document_number(row)
    row['单号'] || row['单据编号'] || ''
  end

  def extract_tracking_number(row)
    if row['操作意见'].present? && row['操作意见'] =~ /快递单号[：:]\s*(\w+)/
      $1.strip
    else
      # 尝试从其他列获取，如果格式固定
      row['快递单号'] || "未知-#{Time.now.to_i}" # 假设有 '快递单号' 列
    end
  end

  def extract_courier_company(row)
    # 示例逻辑，可能需要根据实际数据调整
    if row['操作意见'].present?
      if row['操作意见'].include?('顺丰')
        '顺丰'
      elsif row['操作意见'].include?('圆通')
        '圆通'
      # ... 其他快递公司
      else
        '其他'
      end
    else
      row['快递公司'] || '未知' # 假设有 '快递公司' 列
    end
  end

  def parse_date(date_string)
    return nil unless date_string.present?
    begin
      DateTime.parse(date_string)
    rescue
      DateTime.now # 或者返回 nil
    end
  end
end
```

### 1.3 费用明细导入服务 (FeeDetailImportService)

```ruby
# app/services/fee_detail_import_service.rb
class FeeDetailImportService
  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @imported_count = 0
    @unmatched_count = 0
    @error_count = 0
    @errors = []
    @unmatched_details = []
  end

  def import
    return { success: false, errors: ["文件不存在"] } unless @file.present?

    begin
      spreadsheet = Roo::Spreadsheet.open(@file.path)
      sheet = spreadsheet.sheet(0) # Assuming the first sheet

      # Assuming the first row is headers
      headers = sheet.row(1)
      sheet.each_row_as_hash(headers: true, offset: 1) do |row|
        import_fee_detail(row)
      end

      {
        success: true,
        imported: @imported_count,
        unmatched: @unmatched_count,
        errors: @error_count,
        error_details: @errors,
        unmatched_details: @unmatched_details
      }
    rescue => e
      { success: false, errors: [e.message] }
    end
  end

  private

  def import_fee_detail(row)
    document_number = row['报销单单号']

    # 检查必要字段
    unless document_number.present?
      @error_count += 1
      @errors << "行 #{$.}: 报销单单号不能为空"
      return
    end

    # 查找对应的报销单
    reimbursement = Reimbursement.find_by(invoice_number: document_number)

    unless reimbursement
      # 记录未匹配的费用明细
      @unmatched_count += 1
      @unmatched_details << {
        original_data: row.to_h,
        document_number: document_number,
        error: "报销单不存在"
      }
      return # 报销单不存在，跳过此行
    end

    # 创建费用明细记录
    fee_detail = FeeDetail.new(
      document_number: document_number,
      fee_type: row['费用类型'],
      amount: row['原始金额'],
      currency: 'CNY', # 假设默认为CNY
      fee_date: parse_date(row['费用发生日期']),
      payment_method: row['弹性字段11'], # 假设支付方式在此列
      verification_status: 'pending'
    )

    if fee_detail.save
      @imported_count += 1

      # 如果存在审核工单，自动关联费用明细
      associate_with_audit_work_orders(fee_detail, reimbursement)
    else
      @error_count += 1
      @errors << "行 #{$.}: #{fee_detail.errors.full_messages.join(', ')}"
    end
  end

  def associate_with_audit_work_orders(fee_detail, reimbursement)
    # 查找该报销单的所有未完成的审核工单
    audit_work_orders = AuditWorkOrder.where(reimbursement_id: reimbursement.id).where.not(status: 'completed')

    # 关联到所有处于pending或processing状态的审核工单
    audit_work_orders.where(status: ['pending', 'processing', 'auditing', 'needs_communication']).each do |audit_work_order|
      audit_work_order.select_fee_detail(fee_detail)
    end
  end

  def parse_date(date_string)
    return nil unless date_string.present?
    begin
      DateTime.parse(date_string)
    rescue
      nil
    end
  end
end
```

### 1.4 操作历史导入服务 (OperationHistoryImportService)

```ruby
# app/services/operation_history_import_service.rb
class OperationHistoryImportService
  def initialize(file, current_admin_user)
    @file = file
    @current_admin_user = current_admin_user
    @imported_count = 0
    @updated_count = 0
    @error_count = 0
    @errors = []
    @unmatched_histories = []
  end

  def import
    return { success: false, errors: ["文件不存在"] } unless @file.present?

    begin
      spreadsheet = Roo::Spreadsheet.open(@file.path)
      sheet = spreadsheet.sheet(0) # Assuming the first sheet

      # Assuming the first row is headers
      headers = sheet.row(1)
      sheet.each_row_as_hash(headers: true, offset: 1) do |row|
        import_operation_history(row)
      end

      {
        success: true,
        imported: @imported_count,
        updated: @updated_count,
        errors: @error_count,
        error_details: @errors,
        unmatched_histories: @unmatched_histories
      }
    rescue => e
      { success: false, errors: [e.message] }
    end
  end

  private

  def import_operation_history(row)
    document_number = row['单据编号']
    operation_type = row['操作类型']

    # 检查必要字段
    unless document_number.present? && operation_type.present?
      @error_count += 1
      @errors << "行 #{$.}: 单据编号或操作类型不能为空"
      return
    end

    # 查找对应的报销单
    reimbursement = Reimbursement.find_by(invoice_number: document_number)

    unless reimbursement
      # 记录未匹配的操作历史
      @unmatched_count += 1
      @unmatched_histories << {
        original_data: row.to_h,
        document_number: document_number,
        error: "报销单不存在"
      }
      return # 报销单不存在，跳过此行
    end

    # 创建操作历史记录
    # 注意：假设 OperationHistory 模型存在，如果不存在需要创建或调整
    operation_history = OperationHistory.new(
      document_number: document_number,
      operation_type: operation_type,
      operation_time: parse_date(row['操作日期']),
      operator: row['操作人'],
      notes: row['操作意见']
    )

    if operation_history.save
      @imported_count += 1

      # 检查是否为审批相关操作，并更新报销单状态
      if operation_type.include?('审批通过') || operation_type.include?('已付款') # 根据实际操作类型调整
        reimbursement.mark_as_complete
        @updated_count += 1

        # 可选：根据操作历史强制关闭相关工单
        # update_work_orders(reimbursement)
      end
    else
      @error_count += 1
      @errors << "行 #{$.}: #{operation_history.errors.full_messages.join(', ')}"
    end
  end

  # update_work_orders 方法可能需要根据业务逻辑调整或移除
  # 如果报销单状态完全由外部系统决定，则不应根据操作历史强制关闭工单
  # def update_work_orders(reimbursement)
  #   # ... (逻辑保留或移除)
  # end

  def parse_date(date_string)
    return nil unless date_string.present?
    begin
      DateTime.parse(date_string)
    rescue
      DateTime.now # 或者返回 nil
    end
  end
end
```

## 2. 工单处理服务

### 2.1 审核工单处理服务 (AuditWorkOrderService)

```ruby
# app/services/audit_work_order_service.rb
class AuditWorkOrderService
  def initialize(audit_work_order, current_admin_user)
    @audit_work_order = audit_work_order
    @current_admin_user = current_admin_user
  end

  def start_processing
    @audit_work_order.start_processing! # 使用 bang 方法确保状态转换成功或抛出异常
  end

  def start_audit
    @audit_work_order.start_audit!
  end

  def approve(comment = nil)
    # 确保处于可批准状态
    return false unless @audit_work_order.may_approve?

    result = @audit_work_order.approve! # 使用 bang 方法

    # 更新审核信息 (`state_machines` after 回调已处理)
    @audit_work_order.update(audit_comment: comment) if comment.present?

    # 更新所有关联的费用明细为已验证
    update_associated_fee_details('verified')

    result
  end

  def reject(comment = nil)
    # 确保处于可拒绝状态 (auditing 或 needs_communication)
    return false unless @audit_work_order.may_reject?

    result = @audit_work_order.reject! # 使用 bang 方法

    # 更新审核信息 (`state_machines` after 回调已处理)
    @audit_work_order.update(audit_comment: comment) if comment.present?

    # 更新所有关联的费用明细为已拒绝
    update_associated_fee_details('rejected')

    result
  end

  def need_communication
    @audit_work_order.need_communication!
  end

  def resume_audit
    @audit_work_order.resume_audit!
  end

  def complete
    # 确保处于可完成状态
    return false unless @audit_work_order.may_complete?

    result = @audit_work_order.complete!

    # 检查是否所有审核工单都已完成，更新报销单状态
    # 注意：报销单状态主要由操作历史驱动，此逻辑可能需要调整或移除
    # check_and_complete_reimbursement if result

    result
  end

  def create_communication_work_order(params)
    # 确保处于可创建沟通的状态
    return nil unless @audit_work_order.may_need_communication?

    # 调用模型方法创建沟通工单并更新自身状态
    communication_work_order = @audit_work_order.create_communication_work_order(params.merge(created_by: @current_admin_user.id))

    # 添加初始沟通记录
    if communication_work_order.persisted? && params[:content].present?
      communication_work_order.add_communication_record(
        content: params[:content],
        communicator_role: params[:initiator_role] || 'auditor',
        communicator_name: @current_admin_user.email,
        communication_method: params[:communication_method] || 'system',
        recorded_at: Time.current
      )
    end

    communication_work_order
  end

  def select_fee_details(fee_detail_ids)
    @audit_work_order.select_fee_details(fee_detail_ids)
  end

  def verify_fee_detail(fee_detail_id, result, comment = nil)
    fee_detail = FeeDetail.find(fee_detail_id)
    # 使用 FeeDetailVerificationService 进行验证，确保检查报销单状态
    verification_service = FeeDetailVerificationService.new(@current_admin_user)
    verification_service.update_verification_status(fee_detail, result, comment)
    # 旧逻辑：@audit_work_order.verify_fee_detail(fee_detail, result, comment)
  end

  # mark_fee_detail_problematic 逻辑应包含在 create_communication_work_order 中
  # def mark_fee_detail_problematic(fee_detail_id, issue_description)
  #   # ...
  # end

  private

  def update_associated_fee_details(final_status)
    verification_service = FeeDetailVerificationService.new(@current_admin_user)
    @audit_work_order.fee_details.each do |fee_detail|
      # 只更新未最终确定的费用明细
      unless ['verified', 'rejected'].include?(fee_detail.verification_status)
        verification_service.update_verification_status(fee_detail, final_status)
      end
    end
  end

  # def check_and_complete_reimbursement
  #   reimbursement = @audit_work_order.reimbursement
  #   pending_audit_work_orders = reimbursement.audit_work_orders.where.not(status: 'completed')
  #   if pending_audit_work_orders.empty?
  #     # 报销单状态由操作历史决定，此处不应强制更新
  #     # reimbursement.mark_as_complete
  #   end
  # end
end
```

### 2.2 沟通工单处理服务 (CommunicationWorkOrderService)

```ruby
# app/services/communication_work_order_service.rb
class CommunicationWorkOrderService
  def initialize(communication_work_order, current_admin_user)
    @communication_work_order = communication_work_order
    @current_admin_user = current_admin_user
  end

  def start_communication
    @communication_work_order.start_communication!
  end

  def resolve(resolution_summary = nil)
    return false unless @communication_work_order.may_resolve?
    result = @communication_work_order.resolve! # 模型回调会通知父工单
    @communication_work_order.update(resolution_summary: resolution_summary) if result && resolution_summary.present?
    result
  end

  def mark_unresolved(resolution_summary = nil)
    return false unless @communication_work_order.may_mark_unresolved?
    result = @communication_work_order.mark_unresolved! # 模型回调会通知父工单
    @communication_work_order.update(resolution_summary: resolution_summary) if result && resolution_summary.present?
    result
  end

  def close
    @communication_work_order.close!
  end

  def add_communication_record(params)
    @communication_work_order.add_communication_record(
      params.merge(
        communicator_name: params[:communicator_name] || @current_admin_user.email,
        recorded_at: Time.current
      )
    )
  end

  def resolve_fee_detail_issue(fee_detail_id, resolution)
    fee_detail = FeeDetail.find(fee_detail_id)
    # 此方法只更新沟通工单关联的 FeeDetailSelection 的 comment
    @communication_work_order.resolve_fee_detail_issue(fee_detail, resolution)
  end

  # select_fee_detail 应该在创建沟通工单时处理
  # def select_fee_detail(fee_detail_id)
  #   fee_detail = FeeDetail.find(fee_detail_id)
  #   @communication_work_order.select_fee_detail(fee_detail)
  # end
end
```

### 2.3 快递收单工单处理服务 (ExpressReceiptWorkOrderService)

```ruby
# app/services/express_receipt_work_order_service.rb
class ExpressReceiptWorkOrderService
  def initialize(express_receipt_work_order, current_admin_user)
    @express_receipt_work_order = express_receipt_work_order
    @current_admin_user = current_admin_user
  end

  def process
    @express_receipt_work_order.process!
  end

  def complete
    return false unless @express_receipt_work_order.may_complete?

    result = @express_receipt_work_order.complete! # 模型回调会创建 AuditWorkOrder

    if result
      # 关联报销单的所有费用明细到新创建的审核工单
      audit_work_order = @express_receipt_work_order.audit_work_order
      if audit_work_order
        reimbursement = @express_receipt_work_order.reimbursement
        reimbursement.fee_details.each do |fee_detail|
          # 确保费用明细未被其他审核工单锁定
          unless FeeDetailSelection.exists?(fee_detail_id: fee_detail.id, audit_work_order_id: audit_work_order.id)
             audit_work_order.select_fee_detail(fee_detail)
          end
        end
      end
    end

    result
  end
end
```

## 3. 费用明细验证服务

### 3.1 费用明细验证服务 (FeeDetailVerificationService)

```ruby
# app/services/fee_detail_verification_service.rb
class FeeDetailVerificationService
  def initialize(current_admin_user)
    @current_admin_user = current_admin_user
  end

  # 用于批量更新，可能较少使用
  def verify_fee_details(fee_detail_ids, verification_status, comment = nil)
    results = { success: 0, failure: 0, errors: [] }
    FeeDetail.where(id: fee_detail_ids).each do |fee_detail|
      if update_verification_status(fee_detail, verification_status, comment)
        results[:success] += 1
      else
        results[:failure] += 1
        results[:errors] << "费用明细 ##{fee_detail.id} 更新失败: #{fee_detail.errors.full_messages.join(', ')}"
      end
    end
    results
  end

  # 主要由 AuditWorkOrderService 调用
  def update_verification_status(fee_detail, verification_status, comment = nil)
    # 检查关联报销单是否已关闭
    if fee_detail.reimbursement&.is_complete?
       fee_detail.errors.add(:base, "关联报销单已关闭，无法修改费用明细状态")
       return false
    end

    # 检查状态是否有效
    valid_statuses = FeeDetail::VERIFICATION_STATUSES # 假设模型中定义了常量数组
    unless valid_statuses.include?(verification_status)
      fee_detail.errors.add(:verification_status, "无效的状态")
      return false
    end

    # 更新 FeeDetail 自身状态
    fee_detail.verification_status = verification_status
    unless fee_detail.save
      # 如果保存失败，直接返回 false
      return false
    end

    # 更新所有关联的 FeeDetailSelection 记录
    # 注意：通常只应更新与当前操作相关的工单的 Selection
    # 此处简化为更新所有，但实际应用中可能需要更精确的逻辑
    fee_detail.fee_detail_selections.each do |selection|
      selection.update(
        verification_status: verification_status,
        verification_comment: comment,
        verified_by: @current_admin_user.id,
        verified_at: Time.current
      )
    end

    true
  end

  # 此方法可能不再需要，逻辑移到 AuditWorkOrderService 和 CommunicationWorkOrderService
  # def verify_fee_detail_in_work_order(work_order, fee_detail_id, verification_status, comment = nil)
  #   # ...
  # end

end
```

## 4. 工单状态变更服务

### 4.1 工单状态变更服务 (WorkOrderStatusChangeService)

```ruby
# app/services/work_order_status_change_service.rb
class WorkOrderStatusChangeService
  def initialize(current_admin_user)
    @current_admin_user = current_admin_user
  end

  # 此服务现在可能不是必需的，因为状态变更记录已通过 AASM 回调在模型中处理
  # 如果需要额外的逻辑或从控制器直接记录，可以保留

  def record_status_change(work_order, from_status, to_status, reason = nil)
    work_order_type = case work_order
                      when ExpressReceiptWorkOrder then 'express_receipt'
                      when AuditWorkOrder then 'audit'
                      when CommunicationWorkOrder then 'communication'
                      else raise ArgumentError, "未知的工单类型: #{work_order.class.name}"
                      end

    WorkOrderStatusChange.create!(
      work_order_type: work_order_type,
      work_order_id: work_order.id,
      from_status: from_status,
      to_status: to_status,
      changed_at: Time.current,
      changed_by: @current_admin_user&.id, # 使用安全导航符
      reason: reason
    )
  end

  def get_status_changes(work_order)
    work_order_type = case work_order
                      when ExpressReceiptWorkOrder then 'express_receipt'
                      when AuditWorkOrder then 'audit'
                      when CommunicationWorkOrder then 'communication'
                      else raise ArgumentError, "未知的工单类型: #{work_order.class.name}"
                      end

    WorkOrderStatusChange.where(
      work_order_type: work_order_type,
      work_order_id: work_order.id
    ).order(changed_at: :desc)
  end
end
```

## 5. 服务注册

```ruby
# app/services/service_registry.rb
# 这个模块可能需要根据实际控制器结构调整或移除，
# 直接在控制器中初始化服务通常更清晰。
module ServiceRegistry
  def reimbursement_import_service(file)
    ReimbursementImportService.new(file, current_admin_user)
  end

  def express_receipt_import_service(file)
    ExpressReceiptImportService.new(file, current_admin_user)
  end

  def fee_detail_import_service(file)
    FeeDetailImportService.new(file, current_admin_user)
  end

  def operation_history_import_service(file)
    OperationHistoryImportService.new(file, current_admin_user)
  end

  def audit_work_order_service(work_order)
    AuditWorkOrderService.new(work_order, current_admin_user)
  end

  def communication_work_order_service(work_order)
    CommunicationWorkOrderService.new(work_order, current_admin_user)
  end

  def express_receipt_work_order_service(work_order)
    ExpressReceiptWorkOrderService.new(work_order, current_admin_user)
  end

  def fee_detail_verification_service
    FeeDetailVerificationService.new(current_admin_user)
  end

  # WorkOrderStatusChangeService 可能不再需要注册
  # def work_order_status_change_service
  #   WorkOrderStatusChangeService.new(current_admin_user)
  # end
end
```

## 6. 服务使用示例

以下是在控制器中使用这些服务的示例：

### 6.1 导入控制器

```ruby
# app/controllers/admin/reimbursements_controller.rb
# 示例，具体实现可能在 ActiveAdmin 资源文件中
class Admin::ReimbursementsController < ApplicationController
  # include ServiceRegistry # 或者直接初始化服务

  def new_import
    # 渲染导入表单
  end

  def import
    # 假设文件参数为 params[:file]
    service = ReimbursementImportService.new(params[:file], current_admin_user)
    result = service.import

    if result[:success]
      # 处理成功逻辑，例如重定向和设置 notice
      redirect_to admin_reimbursements_path, notice: "导入成功: #{result[:created]} 创建, #{result[:updated]} 更新, #{result[:errors]} 错误."
    else
      # 处理失败逻辑，例如重定向回导入页面并显示错误
      redirect_to new_import_admin_reimbursements_path, alert: "导入失败: #{result[:errors].join(', ')}"
    end
  end
end
```

### 6.2 工单处理控制器

```ruby
# app/controllers/admin/audit_work_orders_controller.rb
# 示例，具体实现可能在 ActiveAdmin 资源文件中
class Admin::AuditWorkOrdersController < ApplicationController
  # include ServiceRegistry # 或者直接初始化服务
  before_action :set_work_order, except: [:index] # 假设有 index 动作

  def approve
    service = AuditWorkOrderService.new(@work_order, current_admin_user)
    if service.approve(params[:comment])
      redirect_to admin_audit_work_order_path(@work_order), notice: "审核已通过"
    else
      redirect_to admin_audit_work_order_path(@work_order), alert: "操作失败: #{@work_order.errors.full_messages.join(', ')}"
    end
  end

  def reject
    service = AuditWorkOrderService.new(@work_order, current_admin_user)
    if service.reject(params[:comment])
      redirect_to admin_audit_work_order_path(@work_order), notice: "审核已拒绝"
    else
      redirect_to admin_audit_work_order_path(@work_order), alert: "操作失败: #{@work_order.errors.full_messages.join(', ')}"
    end
  end

  def create_communication
    service = AuditWorkOrderService.new(@work_order, current_admin_user)
    communication_work_order = service.create_communication_work_order(communication_params)

    if communication_work_order&.persisted?
      redirect_to admin_communication_work_order_path(communication_work_order), notice: "沟通工单已创建"
    else
      errors = communication_work_order&.errors&.full_messages || @work_order.errors.full_messages
      redirect_to admin_audit_work_order_path(@work_order), alert: "创建沟通工单失败: #{errors.join(', ')}"
    end
  end

  # 其他动作...

  private

  def set_work_order
    @work_order = AuditWorkOrder.find(params[:id])
  end

  def communication_params
    params.require(:communication_work_order).permit(
      :communication_method,
      :initiator_role,
      :content,
      fee_detail_ids: []
    )
  end
end