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