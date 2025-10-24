# frozen_string_literal: true

class WorkOrderOperationRepository
  # Basic query methods
  def self.find(id)
    WorkOrderOperation.find_by(id: id)
  end

  def self.find_by_id(id)
    WorkOrderOperation.find_by(id: id)
  end

  def self.find_by_ids(ids)
    WorkOrderOperation.where(id: ids)
  end

  # WorkOrder-based queries
  def self.by_work_order(work_order_id)
    WorkOrderOperation.where(work_order_id: work_order_id)
  end

  def self.for_work_order(work_order)
    WorkOrderOperation.where(work_order: work_order)
  end

  # AdminUser-based queries
  def self.by_admin_user(admin_user_id)
    WorkOrderOperation.where(admin_user_id: admin_user_id)
  end

  def self.by_admin_user_id(admin_user_id)
    WorkOrderOperation.where(admin_user_id: admin_user_id)
  end

  # Operation type queries
  def self.by_operation_type(operation_type)
    WorkOrderOperation.where(operation_type: operation_type)
  end

  def self.create_operations
    WorkOrderOperation.where(operation_type: WorkOrderOperation::OPERATION_TYPE_CREATE)
  end

  def self.update_operations
    WorkOrderOperation.where(operation_type: WorkOrderOperation::OPERATION_TYPE_UPDATE)
  end

  def self.status_change_operations
    WorkOrderOperation.where(operation_type: WorkOrderOperation::OPERATION_TYPE_STATUS_CHANGE)
  end

  def self.remove_problem_operations
    WorkOrderOperation.where(operation_type: WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM)
  end

  def self.modify_problem_operations
    WorkOrderOperation.where(operation_type: WorkOrderOperation::OPERATION_TYPE_MODIFY_PROBLEM)
  end

  # Date-based queries
  def self.created_today
    WorkOrderOperation.where(created_at: Date.current.all_day)
  end

  def self.created_this_week
    WorkOrderOperation.where(created_at: Date.current.beginning_of_week..Date.current.end_of_week)
  end

  def self.created_this_month
    WorkOrderOperation.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
  end

  def self.by_date_range(start_date, end_date)
    WorkOrderOperation.where(created_at: start_date..end_date)
  end

  # Recent operations
  def self.recent(limit = 10)
    WorkOrderOperation.order(created_at: :desc).limit(limit)
  end

  def self.latest_for_work_order(work_order_id, limit = 5)
    by_work_order(work_order_id).order(created_at: :desc).limit(limit)
  end

  # Count and aggregation methods
  def self.operation_type_counts
    WorkOrderOperation.group(:operation_type).count
  end

  def self.admin_user_counts
    WorkOrderOperation.group(:admin_user_id).count
  end

  def self.count_by_work_order(work_order_id)
    by_work_order(work_order_id).count
  end

  def self.count_by_admin_user(admin_user_id)
    by_admin_user(admin_user_id).count
  end

  # Search functionality
  def self.search_by_details(query)
    return WorkOrderOperation.none if query.blank?

    WorkOrderOperation.where("details LIKE ?", "%#{query}%")
  end

  # Pagination
  def self.page(page_number, per_page = 20)
    WorkOrderOperation.limit(per_page).offset((page_number - 1) * per_page)
  end

  # Existence checks
  def self.exists?(id:)
    WorkOrderOperation.exists?(id: id)
  end

  def self.exists_for_work_order?(work_order_id)
    by_work_order(work_order_id).exists?
  end

  # Performance optimizations
  def self.select_fields(fields)
    WorkOrderOperation.select(fields)
  end

  def self.optimized_list
    WorkOrderOperation.includes(:work_order, :admin_user)
  end

  def self.with_associations
    WorkOrderOperation.includes(:work_order, :admin_user)
  end

  # Error handling
  def self.safe_find(id)
    find(id)
  rescue StandardError => e
    Rails.logger.error "WorkOrderOperationRepository.safe_find error: #{e.message}"
    nil
  end

  def self.safe_find_by_id(id)
    find_by_id(id)
  rescue StandardError => e
    Rails.logger.error "WorkOrderOperationRepository.safe_find_by_id error: #{e.message}"
    nil
  end
end