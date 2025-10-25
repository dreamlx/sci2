# frozen_string_literal: true

class WorkOrderFeeDetailRepository
  # Basic query methods
  def self.find(id)
    WorkOrderFeeDetail.find_by(id: id)
  end

  def self.find_by_id(id)
    WorkOrderFeeDetail.find_by(id: id)
  end

  def self.find_by_ids(ids)
    WorkOrderFeeDetail.where(id: ids)
  end

  # WorkOrder-based queries
  def self.by_work_order(work_order_id)
    WorkOrderFeeDetail.where(work_order_id: work_order_id)
  end

  def self.for_work_order(work_order)
    WorkOrderFeeDetail.where(work_order: work_order)
  end

  def self.find_fee_details_by_work_order(work_order_id)
    by_work_order(work_order_id).includes(:fee_detail).map(&:fee_detail)
  end

  # FeeDetail-based queries
  def self.by_fee_detail(fee_detail_id)
    WorkOrderFeeDetail.where(fee_detail_id: fee_detail_id)
  end

  def self.find_work_orders_by_fee_detail(fee_detail_id)
    by_fee_detail(fee_detail_id).includes(:work_order).map(&:work_order)
  end

  # WorkOrder type queries
  def self.by_work_order_type(type)
    WorkOrderFeeDetail.by_work_order_type(type)
  end

  # Association management
  def self.create_association(work_order_id:, fee_detail_id:)
    WorkOrderFeeDetail.create(
      work_order_id: work_order_id,
      fee_detail_id: fee_detail_id
    )
  end

  def self.remove_association(work_order_id:, fee_detail_id:)
    WorkOrderFeeDetail.find_by(
      work_order_id: work_order_id,
      fee_detail_id: fee_detail_id
    )&.destroy
  end

  def self.batch_associate(work_order_id:, fee_detail_ids:)
    fee_detail_ids.map do |fee_detail_id|
      create_association(work_order_id: work_order_id, fee_detail_id: fee_detail_id)
    end
  end

  # Aggregation methods
  def self.count_fee_details(work_order_id)
    by_work_order(work_order_id).count
  end

  def self.count_work_orders(fee_detail_id)
    by_fee_detail(fee_detail_id).count
  end

  def self.total_amount_for_work_order(work_order_id)
    by_work_order(work_order_id)
      .joins(:fee_detail)
      .sum('fee_details.amount')
  end

  def self.group_by_fee_type(work_order_id)
    by_work_order(work_order_id)
      .joins(:fee_detail)
      .group('fee_details.fee_type')
      .count
  end

  # Existence checks
  def self.exists?(id:)
    WorkOrderFeeDetail.exists?(id: id)
  end

  def self.exists_by_id?(id)
    exists?(id: id)
  end

  def self.association_exists?(work_order_id:, fee_detail_id:)
    WorkOrderFeeDetail.exists?(
      work_order_id: work_order_id,
      fee_detail_id: fee_detail_id
    )
  end

  # Performance optimizations
  def self.with_associations
    WorkOrderFeeDetail.includes(:work_order, :fee_detail)
  end

  def self.optimized_list
    with_associations
  end

  def self.select_fields(fields)
    WorkOrderFeeDetail.select(fields)
  end

  # Pagination
  def self.page(page_number, per_page = 20)
    WorkOrderFeeDetail.limit(per_page).offset((page_number - 1) * per_page)
  end

  # Bulk operations
  def self.where(conditions)
    WorkOrderFeeDetail.where(conditions)
  end

  def self.where_not(conditions)
    WorkOrderFeeDetail.where.not(conditions)
  end

  def self.delete_all(conditions = nil)
    conditions ? WorkOrderFeeDetail.where(conditions).delete_all : WorkOrderFeeDetail.delete_all
  end

  # Error handling
  def self.safe_find(id)
    find(id)
  rescue StandardError => e
    Rails.logger.error "WorkOrderFeeDetailRepository.safe_find error: #{e.message}"
    nil
  end

  def self.safe_find_by_id(id)
    find_by_id(id)
  rescue StandardError => e
    Rails.logger.error "WorkOrderFeeDetailRepository.safe_find_by_id error: #{e.message}"
    nil
  end
end
