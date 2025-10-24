# frozen_string_literal: true

# Repository for ProblemType data access
# Provides a clean interface for database operations and query logic
class ProblemTypeRepository
  # Find operations
  def self.find(id)
    ProblemType.find(id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def self.find_by_id(id)
    ProblemType.find_by(id: id)
  end

  # Batch operations
  def self.find_by_ids(problem_type_ids)
    ProblemType.where(id: problem_type_ids)
  end

  # Query operations
  def self.where(conditions)
    ProblemType.where(conditions)
  end

  def self.where_not(conditions)
    ProblemType.where.not(conditions)
  end

  def self.where_in(field, values)
    ProblemType.where(field => values)
  end

  def self.where_not_in(field, values)
    ProblemType.where.not(field => values)
  end

  # Delegate aggregate methods to ProblemType
  def self.sum(field)
    ProblemType.sum(field)
  end

  def self.group(field)
    ProblemType.group(field)
  end

  def self.select(fields)
    ProblemType.select(fields)
  end

  # Ordering and limiting
  def self.order(field)
    ProblemType.order(field)
  end

  def self.limit(count)
    ProblemType.limit(count)
  end

  def self.offset(count)
    ProblemType.offset(count)
  end

  # Join operations
  def self.joins(associations)
    ProblemType.joins(associations)
  end

  def self.includes(associations)
    ProblemType.includes(associations)
  end

  # Pluck operations
  def self.pluck(field)
    ProblemType.pluck(field)
  end

  def self.distinct_pluck(field)
    ProblemType.distinct.pluck(field)
  end

  # Count operations
  def self.count
    ProblemType.count
  end

  def self.where_count(conditions)
    ProblemType.where(conditions).count
  end

  # Status scopes
  def self.active
    ProblemType.where(active: true)
  end

  def self.inactive
    ProblemType.where(active: false)
  end

  # Fee type-based queries
  def self.by_fee_type(fee_type_id)
    ProblemType.where(fee_type_id: fee_type_id)
  end

  def self.by_fee_types(fee_type_ids)
    ProblemType.where(fee_type_id: fee_type_ids)
  end

  def self.for_fee_type(fee_type)
    by_fee_type(fee_type.id)
  end

  def self.for_fee_types(fee_types)
    fee_type_ids = fee_types.map(&:id)
    by_fee_types(fee_type_ids)
  end

  # Search functionality
  def self.search_by_title(pattern)
    ProblemType.where('title LIKE ?', "%#{pattern}%")
  end

  def self.search_by_issue_code(pattern)
    ProblemType.where('issue_code LIKE ?', "%#{pattern}%")
  end

  def self.search_by_sop_description(pattern)
    ProblemType.where('sop_description LIKE ?', "%#{pattern}%")
  end

  # Pagination support
  def self.page(page_number, per_page = 25)
    limit(per_page).offset((page_number - 1) * per_page)
  end

  # Validation and existence checks
  def self.exists?(conditions)
    ProblemType.exists?(conditions)
  end

  def self.exists_by_id?(id)
    exists?(id: id)
  end

  def self.exists_by_issue_code?(issue_code, fee_type_id = nil)
    if fee_type_id
      exists?(issue_code: issue_code, fee_type_id: fee_type_id)
    else
      exists?(issue_code: issue_code, fee_type_id: nil)
    end
  end

  # Statistics queries
  def self.active_count
    active.count
  end

  def self.inactive_count
    inactive.count
  end

  def self.count_by_fee_type
    group(:fee_type_id).count
  end

  # Performance-optimized queries
  def self.select_fields(fields = [:id, :issue_code, :title, :active, :fee_type_id])
    ProblemType.select(fields)
  end

  def self.optimized_list
    select_fields.includes(:fee_type)
  end

  def self.with_fee_type_details
    includes(:fee_type)
  end

  # Error handling wrapper
  def self.safe_find(id)
    find(id)
  rescue ActiveRecord::RecordNotFound
    nil
  rescue => e
    Rails.logger.error "Error finding problem type #{id}: #{e.message}"
    nil
  end

  def self.safe_find_by_issue_code(issue_code, fee_type_id = nil)
    if fee_type_id
      ProblemType.find_by(issue_code: issue_code, fee_type_id: fee_type_id)
    else
      ProblemType.find_by(issue_code: issue_code, fee_type_id: nil)
    end
  rescue => e
    Rails.logger.error "Error finding problem type by issue code #{issue_code}: #{e.message}"
    nil
  end

  # Complex queries for reporting
  def self.problem_type_summary
    joins(:fee_type)
      .select('problem_types.*, fee_types.name as fee_type_name')
      .order('fee_types.name, problem_types.issue_code')
  end

  def self.active_by_fee_type
    active.joins(:fee_type)
      .select('problem_types.*, fee_types.name as fee_type_name')
      .order('fee_types.name, problem_types.issue_code')
  end

  def self.problem_types_with_work_order_count
    joins('LEFT OUTER JOIN work_orders ON work_orders.problem_type_id = problem_types.id')
      .select('problem_types.*, COUNT(work_orders.id) as work_order_count')
      .group('problem_types.id')
      .order('problem_types.issue_code')
  end
end