# app/services/communication_work_order_service.rb
class CommunicationWorkOrderService
  def initialize(communication_work_order, current_admin_user)
    @service = WorkOrderService.new(communication_work_order, current_admin_user)
  end

  def start_processing(params = {})
    @service.start_processing(params)
  end

  def approve(params = {})
    # Generic service handles common logic including audit_comment for CommunicationWorkOrder.
    @service.approve(params)
  end

  def reject(params = {})
    # Generic service handles common logic including audit_comment and problem_type/description for CommunicationWorkOrder.
    @service.reject(params)
  end

  def update(params = {})
    @service.update(params)
  end
  
  # If CommunicationWorkOrders also handle fee details in the same way
  def update_fee_detail_verification(fee_detail_id, verification_status, comment = nil)
    @service.update_fee_detail_verification(fee_detail_id, verification_status, comment)
  end

  def errors
    @service.work_order.errors
  end
end