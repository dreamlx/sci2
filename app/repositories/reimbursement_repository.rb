# frozen_string_literal: true

# Repository for Reimbursement data access
# Provides a clean interface for database operations and query logic
class ReimbursementRepository
  # Find operations
  def self.find(id)
    Reimbursement.find(id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def self.find_by_id(id)
    Reimbursement.find_by(id: id)
  end

  def self.find_by_invoice_number(invoice_number)
    Reimbursement.find_by(invoice_number: invoice_number)
  end

  def self.find_or_initialize_by_invoice_number(invoice_number)
    Reimbursement.find_or_initialize_by(invoice_number: invoice_number)
  end

  # Batch operations
  def self.find_by_ids(reimbursement_ids)
    Reimbursement.where(id: reimbursement_ids)
  end

  def self.find_each_by_ids(reimbursement_ids, &)
    Reimbursement.where(id: reimbursement_ids).find_each(&)
  end

  def self.find_by_invoice_numbers(invoice_numbers)
    Reimbursement.where(invoice_number: invoice_numbers)
  end

  def self.index_by_invoice_numbers(invoice_numbers)
    Reimbursement.where(invoice_number: invoice_numbers).index_by(&:invoice_number)
  end

  # Query operations
  def self.where(conditions)
    Reimbursement.where(conditions)
  end

  def self.where_not(conditions)
    Reimbursement.where.not(conditions)
  end

  def self.where_in(field, values)
    Reimbursement.where(field => values)
  end

  def self.where_not_in(field, values)
    Reimbursement.where.not(field => values)
  end

  # Ordering and limiting
  def self.order(field)
    Reimbursement.order(field)
  end

  def self.limit(count)
    Reimbursement.limit(count)
  end

  def self.offset(count)
    Reimbursement.offset(count)
  end

  # Join operations
  def self.joins(associations)
    Reimbursement.joins(associations)
  end

  def self.includes(associations)
    Reimbursement.includes(associations)
  end

  # Pluck operations
  def self.pluck(field)
    Reimbursement.pluck(field)
  end

  def self.distinct_pluck(field)
    Reimbursement.distinct.pluck(field)
  end

  def self.distinct_compact_sort_pluck(field)
    Reimbursement.where.not(field => [nil, '']).distinct.pluck(field).compact.sort
  end

  # Count operations
  def self.count
    Reimbursement.count
  end

  def self.where_count(conditions)
    Reimbursement.where(conditions).count
  end

  # Date range queries
  def self.created_between(start_date, end_date)
    Reimbursement.where(created_at: start_date..end_date)
  end

  def self.created_today
    created_between(Date.current.beginning_of_day, Date.current.end_of_day)
  end

  # Status queries
  def self.by_status(status)
    Reimbursement.where(status: status)
  end

  def self.by_statuses(statuses)
    Reimbursement.where(status: statuses)
  end

  def self.pending
    by_status('pending')
  end

  def self.processing
    by_status('processing')
  end

  def self.waiting_completion
    by_status('waiting_completion')
  end

  def self.closed
    by_status('closed')
  end

  # Electronic/non-electronic queries
  def self.electronic
    where(is_electronic: true)
  end

  def self.non_electronic
    where(is_electronic: false)
  end

  # Assignment queries
  def self.my_assignments(user_id)
    assigned_to_user(user_id)
  end

  # Update and notification queries
  def self.with_unread_updates
    where(has_updates: true)
      .where('last_viewed_at IS NULL OR last_update_at > last_viewed_at')
  end

  def self.with_unviewed_operation_histories
    where('last_viewed_operation_histories_at IS NULL OR EXISTS (SELECT 1 FROM operation_histories WHERE operation_histories.document_number = reimbursements.invoice_number AND operation_histories.created_at > reimbursements.last_viewed_operation_histories_at)')
  end

  def self.with_unviewed_express_receipts
    where('last_viewed_express_receipts_at IS NULL OR EXISTS (SELECT 1 FROM work_orders WHERE work_orders.reimbursement_id = reimbursements.id AND work_orders.type = \'ExpressReceiptWorkOrder\' AND work_orders.created_at > COALESCE(reimbursements.last_viewed_express_receipts_at, reimbursements.created_at))')
  end

  def self.with_unviewed_records
    with_unviewed_operation_histories.or(with_unviewed_express_receipts)
  end

  def self.assigned_with_unread_updates(user_id)
    assigned_to_user(user_id).with_unread_updates
  end

  def self.ordered_by_notification_status
    order(has_updates: :desc, last_update_at: :desc)
  end

  # Complex queries
  def self.with_active_assignment
    joins(:active_assignment)
  end

  def self.assigned_to_user(user_id)
    joins(:active_assignment).where(reimbursement_assignments: { assignee_id: user_id })
  end

  def self.with_unread_updates_for_user(_user_id)
    # This would need to be implemented based on the actual business logic
    # for what constitutes "unread updates"
    where(has_updates: true)
  end

  # ERP-related queries
  def self.with_current_approval_node
    where.not(erp_current_approval_node: [nil, ''])
  end

  def self.with_current_approver
    where.not(erp_current_approver: [nil, ''])
  end

  def self.current_approval_nodes
    with_current_approval_node.distinct_compact_sort_pluck(:erp_current_approval_node)
  end

  def self.current_approvers
    with_current_approver.distinct_compact_sort_pluck(:erp_current_approver)
  end

  # Statistics queries
  def self.status_counts
    {
      pending: pending.count,
      processing: processing.count,
      waiting_completion: waiting_completion.count,
      closed: closed.count
    }
  end

  # Search and filtering
  def self.search_by_invoice_number(pattern)
    Reimbursement.where('invoice_number LIKE ?', "%#{pattern}%")
  end

  def self.search_by_erp_field(pattern)
    Reimbursement.where('erp_flexible_field_1 LIKE ? OR erp_flexible_field_2 LIKE ?', "%#{pattern}%", "%#{pattern}%")
  end

  # Pagination support
  def self.page(page_number, per_page = 25)
    limit(per_page).offset((page_number - 1) * per_page)
  end

  # Validation and existence checks
  def self.exists?(conditions)
    Reimbursement.exists?(conditions)
  end

  def self.exists_by_id?(id)
    exists?(id: id)
  end

  def self.exists_by_invoice_number?(invoice_number)
    exists?(invoice_number: invoice_number)
  end

  # Bulk operations
  def self.update_all(updates, conditions = nil)
    if conditions
      where(conditions).update_all(updates)
    else
      Reimbursement.update_all(updates)
    end
  end

  def self.delete_all(conditions = nil)
    if conditions
      where(conditions).delete_all
    else
      Reimbursement.delete_all
    end
  end

  # Custom queries for business logic
  def self.unassigned
    joins('LEFT JOIN reimbursement_assignments ON reimbursements.id = reimbursement_assignments.reimbursement_id AND reimbursement_assignments.is_active = true')
      .where('reimbursement_assignments.id IS NULL')
  end

  def self.overdue
    where('due_date < ?', Date.current)
  end

  def self.recently_created(days = 7)
    where('created_at >= ?', days.days.ago)
  end

  def self.recently_updated(days = 7)
    where('updated_at >= ?', days.days.ago)
  end

  # Complex business queries
  def self.for_user_dashboard(user_id)
    assigned = assigned_to_user(user_id)
    unread = with_unread_updates_for_user(user_id)

    # Combine the queries
    from("(#{assigned.to_sql} UNION #{unread.to_sql}) AS reimbursements")
  end

  # Performance-optimized queries
  def self.select_fields(fields = %i[id invoice_number status created_at])
    Reimbursement.select(fields)
  end

  def self.optimized_list
    select_fields.includes(:active_assignment)
  end

  # Error handling wrapper
  def self.safe_find(id)
    find(id)
  rescue ActiveRecord::RecordNotFound
    nil
  rescue StandardError => e
    Rails.logger.error "Error finding reimbursement #{id}: #{e.message}"
    nil
  end

  def self.safe_find_by_invoice_number(invoice_number)
    find_by_invoice_number(invoice_number)
  rescue StandardError => e
    Rails.logger.error "Error finding reimbursement by invoice #{invoice_number}: #{e.message}"
    nil
  end
end
