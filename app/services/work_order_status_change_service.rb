class WorkOrderStatusChangeService
  attr_reader :admin_user

  def initialize(admin_user)
    @admin_user = admin_user
  end

  def record_status_change(work_order, new_status, comment = nil)
    return false unless work_order.status != new_status

    work_order.update_status(new_status, comment, @admin_user.id)
    create_status_change_record(work_order, new_status)
    notify_audit_team(work_order)
  end

  def get_status_changes(work_order)
    WorkOrderStatusChange.where(work_order_id: work_order.id).order(:change_date => :desc)
  end

  private

  def create_status_change_record(work_order, new_status)
    WorkOrderStatusChange.create!(
      work_order_id: work_order.id,
      previous_status: work_order.status,
      new_status: new_status,
      change_date: Time.current,
      changed_by: @admin_user.id
    )
  end

  def notify_audit_team(work_order)
    # This method can be extended to integrate with a notification service
    Rails.logger.info "Work order #{work_order.id} status changed to #{work_order.status} by #{@admin_user.email}"
  end
end