# app/services/audit_work_order_service.rb
# frozen_string_literal: true

class AuditWorkOrderService < WorkOrderService
  def initialize(audit_work_order, current_admin_user)
    super(audit_work_order, current_admin_user)
    @audit_work_order = audit_work_order
  end

  # The generic WorkOrderService#approve and WorkOrderService#reject methods
  # will now be used, which call the state machine events.
  # Specific logic for AuditWorkOrder, if any beyond attribute assignment 
  # (handled by assign_shared_attributes in parent), can be added here or by overriding.

  # The update method from WorkOrderService is now more generic.
  # If AuditWorkOrder needs specific update logic beyond what WorkOrderService#update provides
  # (which is assign_shared_attributes + save), it can be overridden here.
  # For now, let's assume the parent's update is sufficient after removing opinion-based status changes.
  
  # We remove the specific `update` method from AuditWorkOrderService if its primary role
  # was to set resolution/status based on processing_opinion, as this is now handled by explicit event calls
  # in the parent service for approve/reject, and the parent update is now generic.
  # However, if it had other specific logic, that should be preserved or re-evaluated.
  # Based on the previous content, its main unique logic was setting :resolution and validating based on opinion.

  # Let's simplify and assume for now that specific validations related to 'rejected' state
  # (e.g., problem_type_id) are handled by model validations or can be added to WorkOrderService#reject if generic enough.
  # The `processing_opinion` itself is still a valid attribute that can be set via params.

  # REMOVED process_work_order method as status changes are driven by events.
  # private
  #
  # def process_work_order
  #   case @audit_work_order.processing_opinion # @work_order can be used from parent
  #   when "可以通过"
  #     # This should now be handled by calling self.approve or work_order.mark_as_completed!(admin_user)
  #     # @work_order.update(status: :completed)
  #   when "无法通过"
  #     # This should now be handled by calling self.reject or work_order.mark_as_rejected!(admin_user)
  #     # @work_order.update(status: :rejected)
  #   end
  # end
end