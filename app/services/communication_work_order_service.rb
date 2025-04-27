class CommunicationWorkOrderService
  attr_reader :work_order, :admin_user

  def initialize(work_order, admin_user)
    @work_order = work_order
    @admin_user = admin_user
  end

  def start_communication(comment = nil)
    return false unless can_change_status?

    @work_order.start_communication(comment, @admin_user.id)
    notify_parent_work_order
  end

  def resolve(comment = nil)
    return false unless can_change_status?

    @work_order.resolve(comment, @admin_user.id)
    notify_parent_work_order
  end

  def mark_unresolved(comment = nil)
    return false unless can_change_status?

    @work_order.mark_unresolved(comment, @admin_user.id)
    notify_parent_work_order
  end

  def close(comment = nil)
    return false unless can_change_status?

    @work_order.close(comment, @admin_user.id)
    notify_parent_work_order
  end

  def add_communication_record(content, attachments = [])
    CommunicationRecord.create!(
      communication_work_order_id: @work_order.id,
      content: content,
      attachments: attachments,
      created_by: @admin_user.id
    )
  end

  def resolve_fee_detail_issue(fee_detail_id, comment = nil)
    fee_detail_selection = FeeDetailSelection.find_by(fee_detail_id: fee_detail_id, communication_work_order_id: @work_order.id)

    return false unless fee_detail_selection && can_change_status?

    fee_detail_selection.resolve_issue(comment, @admin_user.id)
    notify_parent_work_order
  end

  private

  def can_change_status?
    @work_order.communicable? && @work_order.status == 'open'
  end

  def notify_parent_work_order
    # This method can be extended to integrate with a notification service
    Rails.logger.info "Communication work order #{@work_order.id} status changed by #{@admin_user.email}"
  end
end