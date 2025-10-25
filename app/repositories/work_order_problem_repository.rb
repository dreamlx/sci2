# frozen_string_literal: true

# Repository for WorkOrderProblem data access
# Provides a clean interface for database operations and query logic
class WorkOrderProblemRepository
  # Find operations
  def self.find(id)
    WorkOrderProblem.find(id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def self.find_by_id(id)
    WorkOrderProblem.find_by(id: id)
  end

  def self.find_by_work_order_id(work_order_id)
    WorkOrderProblem.where(work_order_id: work_order_id)
  end

  def self.find_by_problem_type_id(problem_type_id)
    WorkOrderProblem.where(problem_type_id: problem_type_id)
  end

  # Batch operations
  def self.find_by_ids(problem_ids)
    WorkOrderProblem.where(id: problem_ids)
  end

  def self.find_by_work_order_ids(work_order_ids)
    WorkOrderProblem.where(work_order_id: work_order_ids)
  end

  # Query operations
  def self.where(conditions)
    WorkOrderProblem.where(conditions)
  end

  def self.where_not(conditions)
    WorkOrderProblem.where.not(conditions)
  end

  # Ordering and limiting
  def self.order(field)
    WorkOrderProblem.order(field)
  end

  def self.limit(count)
    WorkOrderProblem.limit(count)
  end

  def self.offset(count)
    WorkOrderProblem.offset(count)
  end

  # Join operations
  def self.joins(associations)
    WorkOrderProblem.joins(associations)
  end

  def self.includes(associations)
    WorkOrderProblem.includes(associations)
  end

  # Count operations
  def self.count
    WorkOrderProblem.count
  end

  def self.where_count(conditions)
    WorkOrderProblem.where(conditions).count
  end

  # Group and statistics
  def self.group_by_problem_type
    WorkOrderProblem.group(:problem_type_id).count
  end

  def self.group_by_work_order
    WorkOrderProblem.group(:work_order_id).count
  end

  # Date range queries
  def self.created_between(start_date, end_date)
    WorkOrderProblem.where(created_at: start_date..end_date)
  end

  def self.created_today
    created_between(Date.current.beginning_of_day, Date.current.end_of_day)
  end

  # Complex queries with associations
  def self.with_work_order
    includes(:work_order)
  end

  def self.with_problem_type
    includes(:problem_type)
  end

  def self.with_all_associations
    WorkOrderProblem.includes(:work_order, :problem_type)
  end

  # Existence checks
  def self.exists?(conditions)
    WorkOrderProblem.exists?(conditions)
  end

  def self.exists_by_id?(id)
    exists?(id: id)
  end

  def self.exists_for_work_order_and_problem_type?(work_order_id, problem_type_id)
    exists?(work_order_id: work_order_id, problem_type_id: problem_type_id)
  end

  # Bulk operations
  def self.create(attributes)
    WorkOrderProblem.create(attributes)
  end

  def self.create!(attributes)
    WorkOrderProblem.create!(attributes)
  end

  def self.update_all(updates, conditions = nil)
    if conditions
      where(conditions).update_all(updates)
    else
      WorkOrderProblem.update_all(updates)
    end
  end

  def self.delete_all(conditions = nil)
    if conditions
      where(conditions).delete_all
    else
      WorkOrderProblem.delete_all
    end
  end

  # Pagination support
  def self.page(page_number, per_page = 25)
    limit(per_page).offset((page_number - 1) * per_page)
  end

  # Performance-optimized queries
  def self.select_fields(fields = %i[id work_order_id problem_type_id created_at])
    WorkOrderProblem.select(fields)
  end

  def self.optimized_list
    select_fields.includes(:work_order, :problem_type)
  end

  # Error handling wrapper
  def self.safe_find(id)
    find(id)
  rescue ActiveRecord::RecordNotFound
    nil
  rescue StandardError => e
    Rails.logger.error "Error finding work order problem #{id}: #{e.message}"
    nil
  end
end
