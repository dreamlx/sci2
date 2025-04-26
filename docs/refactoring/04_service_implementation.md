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
      CSV.foreach(@file.path, headers: true) do |row|
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
      
      # 如果是非电子发票且未收单，创建审核工单
      if !reimbursement.is_electronic && reimbursement.receipt_status != 'received'
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
    AuditWorkOrder.create(
      reimbursement: reimbursement,
      status: 'pending',
      created_by: @current_admin_user.id
    )
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
      CSV.foreach(@file.path, headers: true) do |row|
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
    express_receipt = ExpressReceipt.find(express_receipt_id)
    reimbursement = Reimbursement.find(reimbursement_id)
    
    # 更新快递收单的单据号
    if express_receipt.update(document_number: reimbursement.invoice_number)
      # 更新报销单收单状态
      reimbursement.mark_as_received(express_receipt.receive_date)
      
      # 创建工单
      create_express_receipt_work_order(express_receipt, reimbursement)
      
      return { success: true }
    else
      return { success: false, errors: express_receipt.errors.full_messages }
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
    
    if reimbursement
      # 创建快递收单记录并关联到报销单
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
    else
      # 记录未匹配的快递单
      @unmatched_count += 1
      @unmatched_receipts << {
        original_data: row.to_h,
        document_number: document_number,
        tracking_number: tracking_number
      }
    end
  end
  
  def create_express_receipt_work_order(express_receipt, reimbursement)
    ExpressReceiptWorkOrder.create!(
      reimbursement: reimbursement,
      status: 'received',
      tracking_number: express_receipt.tracking_number,
      received_at: express_receipt.receive_date,
      courier_name: express_receipt.courier_company,
      created_by: @current_admin_user.id
    )
  end
  
  def extract_document_number(row)
    row['单号'] || row['单据编号'] || ''
  end
  
  def extract_tracking_number(row)
    if row['操作意见'].present? && row['操作意见'] =~ /快递单号[：:]\s*(\w+)/
      $1.strip
    else
      "未知-#{Time.now.to_i}"
    end
  end
  
  def extract_courier_company(row)
    if row['操作意见'].present?
      if row['操作意见'].include?('顺丰')
        '顺丰'
      elsif row['操作意见'].include?('圆通')
        '圆通'
      elsif row['操作意见'].include?('中通')
        '中通'
      elsif row['操作意见'].include?('申通')
        '申通'
      elsif row['操作意见'].include?('韵达')
        '韵达'
      else
        '其他'
      end
    else
      '未知'
    end
  end
  
  def parse_date(date_string)
    return nil unless date_string.present?
    begin
      DateTime.parse(date_string)
    rescue
      DateTime.now
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
      CSV.foreach(@file.path, headers: true) do |row|
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
    
    if reimbursement
      # 创建费用明细记录
      fee_detail = FeeDetail.new(
        document_number: document_number,
        fee_type: row['费用类型'],
        amount: row['原始金额'],
        currency: 'CNY',
        fee_date: parse_date(row['费用发生日期']),
        payment_method: row['弹性字段11'],
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
    else
      # 记录未匹配的费用明细
      @unmatched_count += 1
      @unmatched_details << {
        original_data: row.to_h,
        document_number: document_number
      }
    end
  end
  
  def associate_with_audit_work_orders(fee_detail, reimbursement)
    # 查找该报销单的所有审核工单
    audit_work_orders = AuditWorkOrder.where(reimbursement_id: reimbursement.id)
    
    # 关联到所有处于pending或processing状态的审核工单
    audit_work_orders.where(status: ['pending', 'processing']).each do |audit_work_order|
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
  end
  
  def import
    return { success: false, errors: ["文件不存在"] } unless @file.present?
    
    begin
      CSV.foreach(@file.path, headers: true) do |row|
        import_operation_history(row)
      end
      
      {
        success: true,
        imported: @imported_count,
        updated: @updated_count,
        errors: @error_count,
        error_details: @errors
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
    
    # 创建操作历史记录
    operation_history = OperationHistory.new(
      document_number: document_number,
      operation_type: operation_type,
      operation_time: parse_date(row['操作日期']),
      operator: row['操作人'],
      notes: row['操作意见']
    )
    
    if operation_history.save
      @imported_count += 1
      
      # 查找对应的报销单
      reimbursement = Reimbursement.find_by(invoice_number: document_number)
      if reimbursement
        # 检查是否为审批相关操作
        if operation_type.include?('审批') || operation_type.include?('审批通过')
          # 更新报销单状态为已关闭
          reimbursement.mark_as_complete
          @updated_count += 1
          
          # 更新相关工单状态
          update_work_orders(reimbursement)
        end
      end
    else
      @error_count += 1
      @errors << "行 #{$.}: #{operation_history.errors.full_messages.join(', ')}"
    end
  end
  
  def update_work_orders(reimbursement)
    # 更新该报销单的所有审核工单状态
    reimbursement.audit_work_orders.where(status: ['pending', 'processing', 'auditing']).each do |audit_work_order|
      # 如果审核工单尚未完成，则标记为已完成
      audit_work_order.approve if audit_work_order.status == 'auditing'
      audit_work_order.complete if ['approved', 'rejected'].include?(audit_work_order.status)
    end
    
    # 更新该报销单的所有沟通工单状态
    reimbursement.communication_work_orders.where(status: ['open', 'in_progress']).each do |communication_work_order|
      # 如果沟通工单尚未完成，则标记为已解决并关闭
      communication_work_order.resolve(resolution_summary: '基于操作历史自动解决') if communication_work_order.status == 'in_progress'
      communication_work_order.close if ['resolved', 'unresolved'].include?(communication_work_order.status)
    end
  end
  
  def parse_date(date_string)
    return nil unless date_string.present?
    begin
      DateTime.parse(date_string)
    rescue
      DateTime.now
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
    @audit_work_order.start_processing
  end
  
  def start_audit
    @audit_work_order.start_audit
  end
  
  def approve(comment = nil)
    result = @audit_work_order.approve
    
    if result
      # 更新审核信息
      @audit_work_order.update(
        audit_result: 'approved',
        audit_comment: comment,
        audit_date: Time.current
      )
      
      # 更新所有关联的费用明细为已验证
      @audit_work_order.fee_details.each do |fee_detail|
        @audit_work_order.verify_fee_detail(fee_detail, 'verified')
      end
    end
    
    result
  end
  
  def reject(comment = nil)
    result = @audit_work_order.reject
    
    if result
      # 更新审核信息
      @audit_work_order.update(
        audit_result: 'rejected',
        audit_comment: comment,
        audit_date: Time.current
      )
      
      # 更新所有关联的费用明细为已拒绝
      @audit_work_order.fee_details.each do |fee_detail|
        @audit_work_order.verify_fee_detail(fee_detail, 'rejected')
      end
    end
    
    result
  end
  
  def need_communication
    @audit_work_order.need_communication
  end
  
  def resume_audit
    @audit_work_order.resume_audit
  end
  
  def complete
    result = @audit_work_order.complete
    
    if result
      # 如果所有审核工单都已完成，更新报销单状态
      reimbursement = @audit_work_order.reimbursement
      pending_audit_work_orders = reimbursement.audit_work_orders.where.not(status: 'completed')
      
      if pending_audit_work_orders.empty?
        reimbursement.mark_as_complete
      end
    end
    
    result
  end
  
  def create_communication_work_order(params)
    # 创建沟通工单
    communication_work_order = @audit_work_order.create_communication_work_order(
      communication_method: params[:communication_method],
      initiator_role: params[:initiator_role] || 'auditor',
      created_by: @current_admin_user.id,
      fee_detail_ids: params[:fee_detail_ids]
    )
    
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
    @audit_work_order.verify_fee_detail(fee_detail, result, comment)
  end
  
  def mark_fee_detail_problematic(fee_detail_id, issue_description)
    fee_detail = FeeDetail.find(fee_detail_id)
    @audit_work_order.mark_fee_detail_problematic(fee_detail, issue_description)
  end
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
    @communication_work_order.start_communication
  end
  
  def resolve(resolution_summary = nil)
    result = @communication_work_order.resolve
    
    if result && resolution_summary.present?
      @communication_work_order.update(resolution_summary: resolution_summary)
    end
    
    result
  end
  
  def mark_unresolved(resolution_summary = nil)
    result = @communication_work_order.mark_unresolved
    
    if result && resolution_summary.present?
      @communication_work_order.update(resolution_summary: resolution_summary)
    end
    
    result
  end
  
  def close
    @communication_work_order.close
  end
  
  def add_communication_record(params)
    @communication_work_order.add_communication_record(
      content: params[:content],
      communicator_role: params[:communicator_role],
      communicator_name: params[:communicator_name] || @current_admin_user.email,
      communication_method: params[:communication_method] || 'system',
      recorded_at: Time.current
    )
  end
  
  def resolve_fee_detail_issue(fee_detail_id, resolution)
    fee_detail = FeeDetail.find(fee_detail_id)
    @communication_work_order.resolve_fee_detail_issue(fee_detail, resolution)
  end
  
  def select_fee_detail(fee_detail_id)
    fee_detail = FeeDetail.find(fee_detail_id)
    @communication_work_order.select_fee_detail(fee_detail)
  end
end
### 2.3 快递收单工单处理服务 (ExpressReceiptWorkOrderService)

```ruby
# app/services/express_receipt_work_order_service.rb
class ExpressReceiptWorkOrderService
  def initialize(express_receipt_work_order, current_admin_user)
    @express_receipt_work_order = express_receipt_work_order
    @current_admin_user = current_admin_user
  end
  
  def process
    @express_receipt_work_order.process
  end
  
  def complete
    result = @express_receipt_work_order.complete
    
    if result
      # 创建审核工单
      audit_work_order = @express_receipt_work_order.create_audit_work_order
      
      # 关联报销单的所有费用明细到审核工单
      reimbursement = @express_receipt_work_order.reimbursement
      reimbursement.fee_details.each do |fee_detail|
        audit_work_order.select_fee_detail(fee_detail)
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
  
  def verify_fee_details(fee_detail_ids, verification_status, comment = nil)
    results = {
      success: 0,
      failure: 0,
      errors: []
    }
    
    FeeDetail.where(id: fee_detail_ids).each do |fee_detail|
      if update_verification_status(fee_detail, verification_status, comment)
        results[:success] += 1
      else
        results[:failure] += 1
        results[:errors] << "费用明细 ##{fee_detail.id} 更新失败"
      end
    end
    
    results
  end
  
  def verify_fee_detail_in_work_order(work_order, fee_detail_id, verification_status, comment = nil)
    fee_detail = FeeDetail.find(fee_detail_id)
    
    case work_order
    when AuditWorkOrder
      work_order.verify_fee_detail(fee_detail, verification_status, comment)
    when CommunicationWorkOrder
      if verification_status == 'problematic'
        work_order.select_fee_detail(fee_detail)
        true
      else
        work_order.resolve_fee_detail_issue(fee_detail, comment)
      end
    else
      false
    end
  end
  
  private
  
  def update_verification_status(fee_detail, verification_status, comment = nil)
    case verification_status
    when 'verified'
      fee_detail.mark_as_verified
    when 'problematic'
      fee_detail.mark_as_problematic
    when 'rejected'
      fee_detail.mark_as_rejected
    else
      return false
    end
    
    # 更新所有关联的费用明细选择记录
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
  
  def record_status_change(work_order, from_status, to_status, reason = nil)
    work_order_type = case work_order
                      when ExpressReceiptWorkOrder
                        'express_receipt'
                      when AuditWorkOrder
                        'audit'
                      when CommunicationWorkOrder
                        'communication'
                      else
                        raise ArgumentError, "未知的工单类型: #{work_order.class.name}"
                      end
    
    WorkOrderStatusChange.create!(
      work_order_type: work_order_type,
      work_order_id: work_order.id,
      from_status: from_status,
      to_status: to_status,
      changed_at: Time.current,
      changed_by: @current_admin_user.id,
      reason: reason
    )
  end
  
  def get_status_changes(work_order)
    work_order_type = case work_order
                      when ExpressReceiptWorkOrder
                        'express_receipt'
                      when AuditWorkOrder
                        'audit'
                      when CommunicationWorkOrder
                        'communication'
                      else
                        raise ArgumentError, "未知的工单类型: #{work_order.class.name}"
                      end
    
    WorkOrderStatusChange.where(
      work_order_type: work_order_type,
      work_order_id: work_order.id
    ).order(changed_at: :desc)
  end
end
```

## 5. 服务注册

为了方便在控制器中使用这些服务，我们可以创建一个服务注册模块：

```ruby
# app/services/service_registry.rb
module ServiceRegistry
  def reimbursement_import_service
    @reimbursement_import_service ||= ReimbursementImportService.new(params[:file], current_admin_user)
  end
  
  def express_receipt_import_service
    @express_receipt_import_service ||= ExpressReceiptImportService.new(params[:file], current_admin_user)
  end
  
  def fee_detail_import_service
    @fee_detail_import_service ||= FeeDetailImportService.new(params[:file], current_admin_user)
  end
  
  def operation_history_import_service
    @operation_history_import_service ||= OperationHistoryImportService.new(params[:file], current_admin_user)
  end
  
  def audit_work_order_service(work_order)
    @audit_work_order_service ||= AuditWorkOrderService.new(work_order, current_admin_user)
  end
  
  def communication_work_order_service(work_order)
    @communication_work_order_service ||= CommunicationWorkOrderService.new(work_order, current_admin_user)
  end
  
  def express_receipt_work_order_service(work_order)
    @express_receipt_work_order_service ||= ExpressReceiptWorkOrderService.new(work_order, current_admin_user)
  end
  
  def fee_detail_verification_service
    @fee_detail_verification_service ||= FeeDetailVerificationService.new(current_admin_user)
  end
  
  def work_order_status_change_service
    @work_order_status_change_service ||= WorkOrderStatusChangeService.new(current_admin_user)
  end
end
```

## 6. 服务使用示例

以下是在控制器中使用这些服务的示例：

### 6.1 导入控制器

```ruby
# app/controllers/admin/reimbursements_controller.rb
class Admin::ReimbursementsController < ApplicationController
  include ServiceRegistry
  
  def import
    result = reimbursement_import_service.import
    
    if result[:success]
      redirect_to admin_reimbursements_path, notice: "成功导入 #{result[:created]} 条新记录，更新 #{result[:updated]} 条记录"
    else
      redirect_to new_import_admin_reimbursements_path, alert: "导入失败: #{result[:errors].join(', ')}"
    end
  end
end
```

### 6.2 工单处理控制器

```ruby
# app/controllers/admin/audit_work_orders_controller.rb
class Admin::AuditWorkOrdersController < ApplicationController
  include ServiceRegistry
  
  before_action :set_work_order
  
  def approve
    service = audit_work_order_service(@work_order)
    
    if service.approve(params[:comment])
      redirect_to admin_audit_work_order_path(@work_order), notice: "审核已通过"
    else
      redirect_to admin_audit_work_order_path(@work_order), alert: "操作失败"
    end
  end
  
  def reject
    service = audit_work_order_service(@work_order)
    
    if service.reject(params[:comment])
      redirect_to admin_audit_work_order_path(@work_order), notice: "审核已拒绝"
    else
      redirect_to admin_audit_work_order_path(@work_order), alert: "操作失败"
    end
  end
  
  def create_communication
    service = audit_work_order_service(@work_order)
    
    communication_work_order = service.create_communication_work_order(
      communication_method: params[:communication_method],
      initiator_role: params[:initiator_role],
      content: params[:content],
      fee_detail_ids: params[:fee_detail_ids]
    )
    
    if communication_work_order.persisted?
      redirect_to admin_communication_work_order_path(communication_work_order), notice: "沟通工单已创建"
    else
      redirect_to admin_audit_work_order_path(@work_order), alert: "创建沟通工单失败: #{communication_work_order.errors.full_messages.join(', ')}"
    end
  end
  
  private
  
  def set_work_order
    @work_order = AuditWorkOrder.find(params[:id])
  end
end
```
```