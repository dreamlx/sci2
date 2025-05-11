# app/services/audit_work_order_service.rb
class AuditWorkOrderService
  def initialize(audit_work_order, current_admin_user)
    # @audit_work_order = audit_work_order (No longer directly used like this)
    # @current_admin_user = current_admin_user (No longer directly used like this)
    # Current.admin_user = current_admin_user (Set by generic service)
    @service = WorkOrderService.new(audit_work_order, current_admin_user)
  end
  
  def start_processing(params = {})
    @service.start_processing(params)
  end
  
  def approve(params = {})
    # Ensure audit_comment is present as per original AuditWorkOrderService logic
    # This specific check can remain here if it's more stringent for AuditWorkOrder
    # or be fully handled by the generic service if the logic there is sufficient.
    # Generic service already checks for blank audit_comment for AuditWorkOrder.
    @service.approve(params)
  end
  
  def reject(params = {})
    # Generic service already checks for blank audit_comment and problem_type/description for AuditWorkOrder.
    @service.reject(params)
  end
  
  def update(params = {})
    @service.update(params)
  end
  
  def update_fee_detail_verification(fee_detail_id, verification_status, comment = nil)
    @service.update_fee_detail_verification(fee_detail_id, verification_status, comment)
  end

  # Forward any errors from the generic service to the audit_work_order object
  # This might not be strictly necessary if the generic service correctly adds errors to the work_order instance itself.
  # However, if the controller expects errors on @audit_work_order directly from this service wrapper:
  def errors
    @service.work_order.errors
  end
end