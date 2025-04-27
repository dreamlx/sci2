module ServiceRegistry
  # 报销单导入服务
  def reimbursement_import_service(file)
    ReimbursementImportService.new(file, current_admin_user)
  end

  # 快递收单导入服务
  def express_receipt_import_service(file)
    ExpressReceiptImportService.new(file, current_admin_user)
  end

  # 费用明细导入服务
  def fee_detail_import_service(file)
    FeeDetailImportService.new(file, current_admin_user)
  end

  # 操作历史导入服务
  def operation_history_import_service(file)
    OperationHistoryImportService.new(file, current_admin_user)
  end

  # 审核工单处理服务
  def audit_work_order_service(work_order)
    AuditWorkOrderService.new(work_order, current_admin_user)
  end

  # 沟通工单处理服务
  def communication_work_order_service(work_order)
    CommunicationWorkOrderService.new(work_order, current_admin_user)
  end

  # 快递收单工单处理服务
  def express_receipt_work_order_service(work_order)
    ExpressReceiptWorkOrderService.new(work_order, current_admin_user)
  end

  # 费用明细验证服务
  def fee_detail_verification_service
    FeeDetailVerificationService.new(current_admin_user)
  end

  # 工单状态变更服务
  def work_order_status_change_service
    WorkOrderStatusChangeService.new(current_admin_user)
  end
end