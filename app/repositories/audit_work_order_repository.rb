# frozen_string_literal: true

class AuditWorkOrderRepository
  # Basic query methods
  def self.find(id)
    AuditWorkOrder.find_by(id: id)
  end

  def self.find_by_id(id)
    AuditWorkOrder.find_by(id: id)
  end

  def self.find_by_ids(ids)
    AuditWorkOrder.where(id: ids)
  end

  # Audit result queries
  def self.by_audit_result(audit_result)
    AuditWorkOrder.where(audit_result: audit_result)
  end

  def self.approved
    AuditWorkOrder.where(audit_result: 'approved')
  end

  def self.rejected
    AuditWorkOrder.where(audit_result: 'rejected')
  end

  def self.pending_audit
    AuditWorkOrder.where(audit_result: nil)
  end

  # VAT verification queries
  def self.vat_verified
    AuditWorkOrder.where(vat_verified: true)
  end

  def self.vat_not_verified
    AuditWorkOrder.where(vat_verified: false)
  end

  def self.by_vat_verified(vat_verified)
    AuditWorkOrder.where(vat_verified: vat_verified)
  end

  # Status-based queries
  def self.by_status(status)
    AuditWorkOrder.where(status: status)
  end

  def self.pending
    AuditWorkOrder.where(status: 'pending')
  end

  def self.processing
    AuditWorkOrder.where(status: 'processing')
  end

  def self.completed
    AuditWorkOrder.where(status: 'completed')
  end

  def self.status_approved
    AuditWorkOrder.where(status: 'approved')
  end

  def self.status_rejected
    AuditWorkOrder.where(status: 'rejected')
  end

  # Combined queries
  def self.approved_and_vat_verified
    approved.where(vat_verified: true)
  end

  def self.rejected_with_comments
    rejected.where.not(audit_comment: [nil, ''])
  end

  def self.pending_audit_vat_verified
    pending_audit.where(vat_verified: true)
  end

  # Reimbursement-based queries
  def self.for_reimbursement(reimbursement_id)
    AuditWorkOrder.where(reimbursement_id: reimbursement_id)
  end

  def self.by_reimbursement(reimbursement)
    AuditWorkOrder.where(reimbursement: reimbursement)
  end

  # Date-based queries
  def self.audited_today
    AuditWorkOrder.where(audit_date: Date.current.all_day)
  end

  def self.audited_this_week
    AuditWorkOrder.where(audit_date: Date.current.beginning_of_week..Date.current.end_of_week)
  end

  def self.audited_this_month
    AuditWorkOrder.where(audit_date: Date.current.beginning_of_month..Date.current.end_of_month)
  end

  def self.by_audit_date_range(start_date, end_date)
    AuditWorkOrder.where(audit_date: start_date..end_date)
  end

  def self.created_today
    AuditWorkOrder.where(created_at: Date.current.all_day)
  end

  def self.created_this_week
    AuditWorkOrder.where(created_at: Date.current.beginning_of_week..Date.current.end_of_week)
  end

  def self.created_this_month
    AuditWorkOrder.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
  end

  # Count and aggregation methods
  def self.total_count
    AuditWorkOrder.count
  end

  def self.approved_count
    approved.count
  end

  def self.rejected_count
    rejected.count
  end

  def self.pending_audit_count
    pending_audit.count
  end

  def self.vat_verified_count
    vat_verified.count
  end

  def self.vat_not_verified_count
    vat_not_verified.count
  end

  def self.audit_result_counts
    AuditWorkOrder.group(:audit_result).count
  end

  def self.status_counts
    AuditWorkOrder.group(:status).count
  end

  # Search functionality
  def self.search_by_audit_comment(query)
    return AuditWorkOrder.none if query.blank?

    AuditWorkOrder.where('audit_comment LIKE ?', "%#{query}%")
  end

  # Ordering queries
  def self.recent_audits(limit = 10)
    AuditWorkOrder.where.not(audit_date: nil).order(audit_date: :desc).limit(limit)
  end

  def self.recent(limit = 10)
    AuditWorkOrder.order(created_at: :desc).limit(limit)
  end

  def self.oldest_first
    AuditWorkOrder.order(created_at: :asc)
  end

  # Pagination
  def self.page(page_number, per_page = 20)
    AuditWorkOrder.limit(per_page).offset((page_number - 1) * per_page)
  end

  # Existence checks
  def self.exists?(id:)
    AuditWorkOrder.exists?(id: id)
  end

  def self.exists_for_reimbursement?(reimbursement_id)
    for_reimbursement(reimbursement_id).exists?
  end

  def self.has_approved_audit?(reimbursement_id)
    for_reimbursement(reimbursement_id).approved.exists?
  end

  def self.has_rejected_audit?(reimbursement_id)
    for_reimbursement(reimbursement_id).rejected.exists?
  end

  # Performance optimizations
  def self.select_fields(fields)
    AuditWorkOrder.select(fields)
  end

  def self.optimized_list
    AuditWorkOrder.includes(:reimbursement, :creator)
  end

  def self.with_associations
    AuditWorkOrder.includes(:reimbursement, :creator)
  end

  # Error handling
  def self.safe_find(id)
    find(id)
  rescue StandardError => e
    Rails.logger.error "AuditWorkOrderRepository.safe_find error: #{e.message}"
    nil
  end

  def self.safe_find_by_id(id)
    find_by_id(id)
  rescue StandardError => e
    Rails.logger.error "AuditWorkOrderRepository.safe_find_by_id error: #{e.message}"
    nil
  end
end
