# frozen_string_literal: true

class CommunicationRecordRepository
  # Basic query methods
  def self.find(id)
    CommunicationRecord.find_by(id: id)
  end

  def self.find_by_id(id)
    CommunicationRecord.find_by(id: id)
  end

  def self.find_by_ids(ids)
    CommunicationRecord.where(id: ids)
  end

  # CommunicationWorkOrder-based queries
  def self.by_communication_work_order(communication_work_order_id)
    CommunicationRecord.where(communication_work_order_id: communication_work_order_id)
  end

  def self.for_communication_work_order(communication_work_order)
    CommunicationRecord.where(communication_work_order: communication_work_order)
  end

  # Role and method queries
  def self.by_communicator_role(role)
    CommunicationRecord.where(communicator_role: role)
  end

  def self.by_communication_method(method)
    CommunicationRecord.where(communication_method: method)
  end

  def self.by_communicator_name(name)
    CommunicationRecord.where(communicator_name: name)
  end

  # Date-based queries
  def self.recorded_today
    CommunicationRecord.where(recorded_at: Date.current.all_day)
  end

  def self.recorded_this_week
    CommunicationRecord.where(recorded_at: Date.current.beginning_of_week..Date.current.end_of_week)
  end

  def self.recorded_this_month
    CommunicationRecord.where(recorded_at: Date.current.beginning_of_month..Date.current.end_of_month)
  end

  def self.by_date_range(start_date, end_date)
    CommunicationRecord.where(recorded_at: start_date..end_date)
  end

  # Recent records
  def self.recent(limit = 10)
    CommunicationRecord.order(recorded_at: :desc).limit(limit)
  end

  def self.latest_for_work_order(communication_work_order_id, limit = 5)
    by_communication_work_order(communication_work_order_id)
      .order(recorded_at: :desc)
      .limit(limit)
  end

  # Search functionality
  def self.search_content(query)
    return CommunicationRecord.none if query.blank?

    CommunicationRecord.where('content LIKE ?', "%#{query}%")
  end

  # Count and aggregation methods
  def self.count_by_work_order(communication_work_order_id)
    by_communication_work_order(communication_work_order_id).count
  end

  def self.count_by_role(role)
    by_communicator_role(role).count
  end

  def self.role_counts
    CommunicationRecord.group(:communicator_role).count
  end

  def self.method_counts
    CommunicationRecord.group(:communication_method).count
  end

  # Existence checks
  def self.exists?(id:)
    CommunicationRecord.exists?(id: id)
  end

  def self.exists_by_id?(id)
    exists?(id: id)
  end

  def self.exists_for_work_order?(communication_work_order_id)
    by_communication_work_order(communication_work_order_id).exists?
  end

  # Performance optimizations
  def self.with_associations
    CommunicationRecord.includes(:communication_work_order)
  end

  def self.optimized_list
    with_associations
  end

  def self.select_fields(fields)
    CommunicationRecord.select(fields)
  end

  # Pagination
  def self.page(page_number, per_page = 20)
    CommunicationRecord.limit(per_page).offset((page_number - 1) * per_page)
  end

  # Bulk operations
  def self.where(conditions)
    CommunicationRecord.where(conditions)
  end

  def self.where_not(conditions)
    CommunicationRecord.where.not(conditions)
  end

  def self.create(attributes)
    CommunicationRecord.create(attributes)
  end

  def self.create!(attributes)
    CommunicationRecord.create!(attributes)
  end

  def self.batch_create(records)
    records.map { |record| create(record) }
  end

  def self.delete_all(conditions = nil)
    conditions ? CommunicationRecord.where(conditions).delete_all : CommunicationRecord.delete_all
  end

  # Error handling
  def self.safe_find(id)
    find(id)
  rescue StandardError => e
    Rails.logger.error "CommunicationRecordRepository.safe_find error: #{e.message}"
    nil
  end

  def self.safe_find_by_id(id)
    find_by_id(id)
  rescue StandardError => e
    Rails.logger.error "CommunicationRecordRepository.safe_find_by_id error: #{e.message}"
    nil
  end

  # Sorting
  def self.order_by_date(direction = :desc)
    CommunicationRecord.order(recorded_at: direction)
  end

  def self.oldest_first
    order_by_date(:asc)
  end

  def self.newest_first
    order_by_date(:desc)
  end
end
