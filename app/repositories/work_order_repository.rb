# frozen_string_literal: true

class WorkOrderRepository
  # Basic query methods
  def self.find(id)
    WorkOrder.find_by(id: id)
  end

  def self.find_by_id(id)
    WorkOrder.find_by(id: id)
  end

  def self.find_by_ids(ids)
    WorkOrder.where(id: ids)
  end

  # Status-based queries
  # Note: WorkOrder doesn't have active field, using status instead
  def self.active_status
    WorkOrder.where(status: %w[pending processing])
  end

  def self.by_status(status)
    WorkOrder.where(status: status)
  end

  def self.pending
    WorkOrder.where(status: 'pending')
  end

  def self.processing
    WorkOrder.where(status: 'processing')
  end

  def self.completed
    WorkOrder.where(status: 'completed')
  end

  # Reimbursement-based queries
  def self.for_reimbursement(reimbursement)
    WorkOrder.where(reimbursement_id: reimbursement.id)
  end

  def self.by_document_number(document_number)
    reimbursement = Reimbursement.find_by(invoice_number: document_number)
    return WorkOrder.none unless reimbursement

    for_reimbursement(reimbursement)
  end

  # Type-specific queries
  def self.audit_work_orders
    WorkOrder.where(type: 'AuditWorkOrder')
  end

  def self.communication_work_orders
    WorkOrder.where(type: 'CommunicationWorkOrder')
  end

  def self.express_receipt_work_orders
    WorkOrder.where(type: 'ExpressReceiptWorkOrder')
  end

  # Assignment-based queries
  def self.assigned_to(assignee_id)
    WorkOrder.where(assignee_id: assignee_id)
  end

  def self.unassigned
    WorkOrder.where(assignee_id: nil)
  end

  # Date-based queries
  def self.created_today
    WorkOrder.where(created_at: Date.current.all_day)
  end

  def self.created_this_week
    WorkOrder.where(created_at: Date.current.beginning_of_week..Date.current.end_of_week)
  end

  def self.created_this_month
    WorkOrder.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
  end

  # Count and aggregation methods
  def self.status_counts
    WorkOrder.group(:status).count
  end

  def self.type_counts
    WorkOrder.group(:type).count
  end

  def self.active_count
    active_status.count
  end

  def self.pending_count
    pending.count
  end

  def self.processing_count
    processing.count
  end

  def self.completed_count
    completed.count
  end

  # Search functionality
  def self.search_by_notes(query)
    return WorkOrder.none if query.blank?

    WorkOrder.where("notes ILIKE ?", "%#{query}%")
  end

  # Pagination and ordering
  def self.recent(limit = 10)
    WorkOrder.order(created_at: :desc).limit(limit)
  end

  def self.page(page_number, per_page = 20)
    WorkOrder.limit(per_page).offset((page_number - 1) * per_page)
  end

  # Existence checks
  def self.exists?(id:)
    WorkOrder.exists?(id: id)
  end

  def self.exists_for_reimbursement?(reimbursement_id)
    for_reimbursement_id(reimbursement_id).exists?
  end

  # Performance optimizations
  def self.select_fields(fields)
    WorkOrder.select(fields)
  end

  def self.optimized_list
    WorkOrder.includes(:reimbursement, :assignee)
  end

  # Error handling
  def self.safe_find(id)
    find(id)
  rescue StandardError => e
    Rails.logger.error "WorkOrderRepository.safe_find error: #{e.message}"
    nil
  end

  def self.safe_find_by_id(id)
    find_by_id(id)
  rescue StandardError => e
    Rails.logger.error "WorkOrderRepository.safe_find_by_id error: #{e.message}"
    nil
  end
end