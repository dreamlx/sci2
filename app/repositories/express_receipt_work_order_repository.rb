# frozen_string_literal: true

class ExpressReceiptWorkOrderRepository
  # Basic query methods
  def self.find(id)
    ExpressReceiptWorkOrder.find_by(id: id)
  end

  def self.find_by_id(id)
    ExpressReceiptWorkOrder.find_by(id: id)
  end

  def self.find_by_ids(ids)
    ExpressReceiptWorkOrder.where(id: ids)
  end

  # Tracking number queries
  def self.by_tracking_number(tracking_number)
    ExpressReceiptWorkOrder.where(tracking_number: tracking_number)
  end

  def self.find_by_tracking_number(tracking_number)
    ExpressReceiptWorkOrder.find_by(tracking_number: tracking_number)
  end

  # Filling ID queries
  def self.by_filling_id(filling_id)
    ExpressReceiptWorkOrder.where(filling_id: filling_id)
  end

  def self.find_by_filling_id(filling_id)
    ExpressReceiptWorkOrder.find_by(filling_id: filling_id)
  end

  # Courier queries
  def self.by_courier_name(courier_name)
    ExpressReceiptWorkOrder.where(courier_name: courier_name)
  end

  # Status queries (always completed)
  def self.by_status(status)
    ExpressReceiptWorkOrder.where(status: status)
  end

  def self.completed
    ExpressReceiptWorkOrder.where(status: 'completed')
  end

  def self.all_completed
    ExpressReceiptWorkOrder.all # All express receipts should be completed
  end

  # Reimbursement-based queries
  def self.for_reimbursement(reimbursement_id)
    ExpressReceiptWorkOrder.where(reimbursement_id: reimbursement_id)
  end

  def self.by_reimbursement(reimbursement)
    ExpressReceiptWorkOrder.where(reimbursement: reimbursement)
  end

  # Received date queries
  def self.received_today
    ExpressReceiptWorkOrder.where(received_at: Date.current.all_day)
  end

  def self.received_this_week
    ExpressReceiptWorkOrder.where(received_at: Date.current.beginning_of_week..Date.current.end_of_week)
  end

  def self.received_this_month
    ExpressReceiptWorkOrder.where(received_at: Date.current.beginning_of_month..Date.current.end_of_month)
  end

  def self.by_received_date_range(start_date, end_date)
    ExpressReceiptWorkOrder.where(received_at: start_date..end_date)
  end

  # Creation date queries
  def self.created_today
    ExpressReceiptWorkOrder.where(created_at: Date.current.all_day)
  end

  def self.created_this_week
    ExpressReceiptWorkOrder.where(created_at: Date.current.beginning_of_week..Date.current.end_of_week)
  end

  def self.created_this_month
    ExpressReceiptWorkOrder.where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
  end

  # Count and aggregation methods
  def self.total_count
    ExpressReceiptWorkOrder.count
  end

  def self.courier_counts
    ExpressReceiptWorkOrder.group(:courier_name).count
  end

  def self.received_count_by_date(date)
    ExpressReceiptWorkOrder.where(received_at: date.all_day).count
  end

  # Ordering queries
  def self.recent(limit = 10)
    ExpressReceiptWorkOrder.order(created_at: :desc).limit(limit)
  end

  def self.recent_received(limit = 10)
    ExpressReceiptWorkOrder.order(received_at: :desc).limit(limit)
  end

  def self.recent_first
    ExpressReceiptWorkOrder.order(created_at: :desc)
  end

  def self.oldest_first
    ExpressReceiptWorkOrder.order(created_at: :asc)
  end

  # Pagination
  def self.page(page_number, per_page = 20)
    ExpressReceiptWorkOrder.limit(per_page).offset((page_number - 1) * per_page)
  end

  # Existence checks
  def self.exists?(id:)
    ExpressReceiptWorkOrder.exists?(id: id)
  end

  def self.exists_for_reimbursement?(reimbursement_id)
    for_reimbursement(reimbursement_id).exists?
  end

  def self.exists_by_tracking_number?(tracking_number)
    by_tracking_number(tracking_number).exists?
  end

  def self.exists_by_filling_id?(filling_id)
    by_filling_id(filling_id).exists?
  end

  # Performance optimizations
  def self.select_fields(fields)
    ExpressReceiptWorkOrder.select(fields)
  end

  def self.optimized_list
    ExpressReceiptWorkOrder.includes(:reimbursement, :creator)
  end

  def self.with_associations
    ExpressReceiptWorkOrder.includes(:reimbursement, :creator)
  end

  # Error handling
  def self.safe_find(id)
    find(id)
  rescue StandardError => e
    Rails.logger.error "ExpressReceiptWorkOrderRepository.safe_find error: #{e.message}"
    nil
  end

  def self.safe_find_by_id(id)
    find_by_id(id)
  rescue StandardError => e
    Rails.logger.error "ExpressReceiptWorkOrderRepository.safe_find_by_id error: #{e.message}"
    nil
  end

  def self.safe_find_by_tracking_number(tracking_number)
    find_by_tracking_number(tracking_number)
  rescue StandardError => e
    Rails.logger.error "ExpressReceiptWorkOrderRepository.safe_find_by_tracking_number error: #{e.message}"
    nil
  end
end
