# frozen_string_literal: true

class CommunicationWorkOrderRepository
  # Basic query methods
  def self.find(id)
    CommunicationWorkOrder.find_by(id: id)
  end

  def self.find_by_id(id)
    CommunicationWorkOrder.find_by(id: id)
  end

  def self.find_by_ids(ids)
    CommunicationWorkOrder.where(id: ids)
  end

  # Communication method queries
  def self.by_communication_method(method)
    CommunicationWorkOrder.where(communication_method: method)
  end

  # Status-based queries
  def self.by_status(status)
    CommunicationWorkOrder.where(status: status)
  end

  def self.pending
    CommunicationWorkOrder.where(status: 'pending')
  end

  def self.processing
    CommunicationWorkOrder.where(status: 'processing')
  end

  def self.completed
    CommunicationWorkOrder.where(status: 'completed')
  end

  # Reimbursement-based queries
  def self.for_reimbursement(reimbursement_id)
    CommunicationWorkOrder.where(reimbursement_id: reimbursement_id)
  end

  def self.by_reimbursement(reimbursement)
    CommunicationWorkOrder.where(reimbursement: reimbursement)
  end

  # Comment queries
  def self.with_comments
    CommunicationWorkOrder.where.not(audit_comment: [nil, ''])
  end

  def self.search_by_audit_comment(query)
    return CommunicationWorkOrder.none if query.blank?

    CommunicationWorkOrder.where('audit_comment LIKE ?', "%#{query}%")
  end

  # Date-based queries
  def self.created_today
    CommunicationWorkOrder.where(created_at: Date.current.all_day)
  end

  def self.created_this_week
    CommunicationWorkOrder.where(created_at: Date.current.beginning_of_week..Date.current.end_of_week)
  end

  def self.created_this_month
    CommunicationWorkOrder.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
  end

  # Count and aggregation methods
  def self.total_count
    CommunicationWorkOrder.count
  end

  def self.completed_count
    completed.count
  end

  def self.communication_method_counts
    CommunicationWorkOrder.group(:communication_method).count
  end

  def self.status_counts
    CommunicationWorkOrder.group(:status).count
  end

  # Ordering queries
  def self.recent(limit = 10)
    CommunicationWorkOrder.order(created_at: :desc).limit(limit)
  end

  def self.recent_first
    CommunicationWorkOrder.order(created_at: :desc)
  end

  def self.oldest_first
    CommunicationWorkOrder.order(created_at: :asc)
  end

  # Pagination
  def self.page(page_number, per_page = 20)
    CommunicationWorkOrder.limit(per_page).offset((page_number - 1) * per_page)
  end

  # Existence checks
  def self.exists?(id:)
    CommunicationWorkOrder.exists?(id: id)
  end

  def self.exists_for_reimbursement?(reimbursement_id)
    for_reimbursement(reimbursement_id).exists?
  end

  # Performance optimizations
  def self.select_fields(fields)
    CommunicationWorkOrder.select(fields)
  end

  def self.optimized_list
    CommunicationWorkOrder.includes(:reimbursement, :creator)
  end

  def self.with_associations
    CommunicationWorkOrder.includes(:reimbursement, :creator)
  end

  # Error handling
  def self.safe_find(id)
    find(id)
  rescue StandardError => e
    Rails.logger.error "CommunicationWorkOrderRepository.safe_find error: #{e.message}"
    nil
  end

  def self.safe_find_by_id(id)
    find_by_id(id)
  rescue StandardError => e
    Rails.logger.error "CommunicationWorkOrderRepository.safe_find_by_id error: #{e.message}"
    nil
  end
end
