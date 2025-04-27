class AuditWorkOrderService
  attr_reader :work_order, :admin_user

  def initialize(work_order, admin_user)
    @work_order = work_order
    @admin_user = admin_user
  end

  def start_processing(comment = nil)
    return false unless can_change_status?

    @work_order.start_processing(comment, @admin_user.id)
    notify_audit_team
  end

  def start_audit(comment = nil)
    return false unless can_change_status?

    @work_order.start_audit(comment, @admin_user.id)
    notify_audit_team
  end

  def approve(comment = nil)
    return false unless can_change_status?

    @work_order.approve(comment, @admin_user.id)
    notify_audit_team
  end

  def reject(comment = nil)
    return false unless can_change_status?

    @work_order.reject(comment, @admin_user.id)
    notify_audit_team
  end

  def need_communication(comment = nil)
    return false unless can_change_status?

    @work_order.need_communication(comment, @admin_user.id)
    create_communication_work_order
    notify_audit_team
  end

  def resume_audit(comment = nil)
    return false unless can_change_status?

    @work_order.resume_audit(comment, @admin_user.id)
    notify_audit_team
  end

  def complete(comment = nil)
    return false unless can_change_status?

    @work_order.complete(comment, @admin_user.id)
    notify_audit_team
  end

  def create_communication_work_order
    CommunicationWorkOrder.create!(
      reimbursement: @work_order.reimbursement,
      audit_work_order: @work_order,
      status: 'open',
      created_by: @admin_user.id
    )
  end

  private

  def can_change_status?
    @work_order.auditable? && @work_order.status == 'pending'
  end

  def notify_audit_team
    # This method can be extended to integrate with a notification service
    Rails.logger.info "Audit work order #{@work_order.id} status changed by #{@admin_user.email}"
  end
end