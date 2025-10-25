# frozen_string_literal: true

class ReimbursementAssignmentRepository
  # Basic query methods
  def self.find(id)
    ReimbursementAssignment.find_by(id: id)
  end

  def self.find_by_id(id)
    ReimbursementAssignment.find_by(id: id)
  end

  def self.find_by_ids(ids)
    ReimbursementAssignment.where(id: ids)
  end

  # Assignment status queries
  def self.active
    ReimbursementAssignment.active
  end

  def self.inactive
    ReimbursementAssignment.where(is_active: false)
  end

  def self.by_assignee(assignee_id)
    ReimbursementAssignment.by_assignee(assignee_id)
  end

  def self.by_assigner(assigner_id)
    ReimbursementAssignment.by_assigner(assigner_id)
  end

  # Combined status and user queries
  def self.active_by_assignee(assignee_id)
    active.by_assignee(assignee_id)
  end

  def self.active_by_assigner(assigner_id)
    active.by_assigner(assigner_id)
  end

  def self.inactive_by_assignee(assignee_id)
    inactive.by_assignee(assignee_id)
  end

  def self.inactive_by_assigner(assigner_id)
    inactive.by_assigner(assigner_id)
  end

  # Reimbursement-based queries
  def self.for_reimbursement(reimbursement_id)
    ReimbursementAssignment.where(reimbursement_id: reimbursement_id)
  end

  def self.active_for_reimbursement(reimbursement_id)
    for_reimbursement(reimbursement_id).active
  end

  def self.current_for_reimbursement(reimbursement_id)
    active_for_reimbursement(reimbursement_id).first
  end

  # Complex queries
  def self.recent_first
    ReimbursementAssignment.recent_first
  end

  def self.active_recent_first
    active.recent_first
  end

  def self.by_assignee_recent(assignee_id)
    by_assignee(assignee_id).recent_first
  end

  def self.active_by_assignee_recent(assignee_id)
    active_by_assignee(assignee_id).recent_first
  end

  # Uniqueness validation queries
  def self.exists_active_for_reimbursement?(reimbursement_id)
    active_for_reimbursement(reimbursement_id).exists?
  end

  def self.active_assignment_for_reimbursement(reimbursement_id)
    active_for_reimbursement(reimbursement_id).first
  end

  # Date-based queries
  def self.created_today
    ReimbursementAssignment.where(created_at: Date.current.all_day)
  end

  def self.created_this_week
    ReimbursementAssignment.where(created_at: Date.current.beginning_of_week..Date.current.end_of_week)
  end

  def self.created_this_month
    ReimbursementAssignment.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
  end

  def self.active_created_today
    created_today.active
  end

  # Count and aggregation methods
  def self.total_count
    ReimbursementAssignment.count
  end

  def self.active_count
    active.count
  end

  def self.inactive_count
    inactive.count
  end

  def self.count_by_assignee(assignee_id)
    by_assignee(assignee_id).count
  end

  def self.active_count_by_assignee(assignee_id)
    active_by_assignee(assignee_id).count
  end

  def self.count_by_assigner(assigner_id)
    by_assigner(assigner_id).count
  end

  def self.active_count_by_assigner(assigner_id)
    active_by_assigner(assigner_id).count
  end

  def self.assignee_counts
    by_assignee(nil).joins(:assignee).group('admin_users.name').count
  end

  def self.assigner_counts
    by_assigner(nil).joins(:assigner).group('admin_users.name').count
  end

  # Search functionality
  def self.search_by_notes(query)
    return ReimbursementAssignment.none if query.blank?

    ReimbursementAssignment.where("notes LIKE ?", "%#{query}%")
  end

  def self.active_search_by_notes(query)
    return active if query.blank?

    active.where("notes LIKE ?", "%#{query}%")
  end

  # Pagination and ordering
  def self.recent(limit = 10)
    recent_first.limit(limit)
  end

  def self.active_recent(limit = 10)
    active_recent_first.limit(limit)
  end

  def self.page(page_number, per_page = 20)
    ReimbursementAssignment.limit(per_page).offset((page_number - 1) * per_page)
  end

  def self.active_page(page_number, per_page = 20)
    active.limit(per_page).offset((page_number - 1) * per_page)
  end

  # Existence checks
  def self.exists?(id:)
    ReimbursementAssignment.exists?(id: id)
  end

  def self.exists_for_reimbursement?(reimbursement_id)
    for_reimbursement(reimbursement_id).exists?
  end

  def self.has_active_assignment?(reimbursement_id)
    exists_active_for_reimbursement?(reimbursement_id)
  end

  # Performance optimizations
  def self.select_fields(fields)
    ReimbursementAssignment.select(fields)
  end

  def self.optimized_list
    ReimbursementAssignment.includes(:reimbursement, :assignee, :assigner)
  end

  def self.active_optimized_list
    optimized_list.active
  end

  def self.optimized_for_reimbursement(reimbursement_id)
    for_reimbursement(reimbursement_id).includes(:assignee, :assigner)
  end

  # Error handling
  def self.safe_find(id)
    find(id)
  rescue StandardError => e
    Rails.logger.error "ReimbursementAssignmentRepository.safe_find error: #{e.message}"
    nil
  end

  def self.safe_find_by_id(id)
    find_by_id(id)
  rescue StandardError => e
    Rails.logger.error "ReimbursementAssignmentRepository.safe_find_by_id error: #{e.message}"
    nil
  end

  def self.safe_current_for_reimbursement(reimbursement_id)
    current_for_reimbursement(reimbursement_id)
  rescue StandardError => e
    Rails.logger.error "ReimbursementAssignmentRepository.safe_current_for_reimbursement error: #{e.message}"
    nil
  end
end