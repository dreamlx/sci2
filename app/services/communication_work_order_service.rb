# app/services/communication_work_order_service.rb
class CommunicationWorkOrderService < WorkOrderService
  def initialize(communication_work_order, current_admin_user)
    super(communication_work_order, current_admin_user)
    # @work_order will be the communication_work_order instance from super
    # and is accessible as @work_order or work_order (attr_reader from parent)
  end

  # All core methods (approve, reject, update, update_fee_detail_verification)
  # are now inherited from WorkOrderService.
  # Override them here ONLY if CommunicationWorkOrder needs *different*
  # service-level behavior for these actions than the generic one.

  # The errors method can also be inherited if work_order.errors is sufficient,
  # or customize if needed.
  # def errors
  #   @work_order.errors
  # end
end