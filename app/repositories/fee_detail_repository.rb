# frozen_string_literal: true

# Repository for FeeDetail data access
# Provides a clean interface for database operations and query logic
class FeeDetailRepository
  # Find operations
  def self.find(id)
    FeeDetail.find(id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def self.find_by_id(id)
    FeeDetail.find_by(id: id)
  end

  def self.find_by_external_fee_id(external_fee_id)
    FeeDetail.find_by(external_fee_id: external_fee_id)
  end

  def self.find_or_create_by_external_fee_id(external_fee_id, attributes = {})
    FeeDetail.find_or_create_by(external_fee_id: external_fee_id) do |fee_detail|
      fee_detail.assign_attributes(attributes)
    end
  end

  # Batch operations
  def self.find_by_ids(fee_detail_ids)
    FeeDetail.where(id: fee_detail_ids)
  end

  def self.find_by_external_fee_ids(external_fee_ids)
    FeeDetail.where(external_fee_id: external_fee_ids)
  end

  def self.find_each_by_ids(fee_detail_ids, &)
    FeeDetail.where(id: fee_detail_ids).find_each(&)
  end

  # Query operations
  def self.where(conditions)
    FeeDetail.where(conditions)
  end

  def self.where_not(conditions)
    FeeDetail.where.not(conditions)
  end

  def self.where_in(field, values)
    FeeDetail.where(field => values)
  end

  def self.where_not_in(field, values)
    FeeDetail.where.not(field => values)
  end

  # Delegate aggregate methods to FeeDetail
  def self.sum(field)
    FeeDetail.sum(field)
  end

  def self.group(field)
    FeeDetail.group(field)
  end

  def self.select(fields)
    FeeDetail.select(fields)
  end

  # Ordering and limiting
  def self.order(field)
    FeeDetail.order(field)
  end

  def self.limit(count)
    FeeDetail.limit(count)
  end

  def self.offset(count)
    FeeDetail.offset(count)
  end

  # Join operations
  def self.joins(associations)
    FeeDetail.joins(associations)
  end

  def self.includes(associations)
    FeeDetail.includes(associations)
  end

  # Pluck operations
  def self.pluck(field)
    FeeDetail.pluck(field)
  end

  def self.distinct_pluck(field)
    FeeDetail.distinct.pluck(field)
  end

  # Count operations
  def self.count
    FeeDetail.count
  end

  def self.where_count(conditions)
    FeeDetail.where(conditions).count
  end

  # Status scopes
  def self.by_status(status)
    FeeDetail.where(verification_status: status)
  end

  def self.by_statuses(statuses)
    FeeDetail.where(verification_status: statuses)
  end

  def self.pending
    by_status('pending')
  end

  def self.problematic
    by_status('problematic')
  end

  def self.verified
    by_status('verified')
  end

  # Document-based queries
  def self.by_document(document_number)
    FeeDetail.where(document_number: document_number)
  end

  def self.by_documents(document_numbers)
    FeeDetail.where(document_number: document_numbers)
  end

  # Reimbursement-based queries
  def self.for_reimbursement(reimbursement)
    by_document(reimbursement.invoice_number)
  end

  def self.for_reimbursements(reimbursements)
    document_numbers = reimbursements.map(&:invoice_number)
    by_documents(document_numbers)
  end

  # Amount-based queries
  def self.with_amount_greater_than(amount)
    FeeDetail.where('amount > ?', amount)
  end

  def self.with_amount_between(min_amount, max_amount)
    FeeDetail.where('amount BETWEEN ? AND ?', min_amount, max_amount)
  end

  # Date-based queries
  def self.created_between(start_date, end_date)
    where(created_at: start_date..end_date)
  end

  def self.fee_date_between(start_date, end_date)
    where(fee_date: start_date..end_date)
  end

  def self.created_today
    created_between(Date.current.beginning_of_day, Date.current.end_of_day)
  end

  def self.created_this_month
    created_between(Date.current.beginning_of_month, Date.current.end_of_month)
  end

  # Search and filtering
  def self.search_by_fee_type(pattern)
    FeeDetail.where('fee_type LIKE ?', "%#{pattern}%")
  end

  def self.search_by_notes(pattern)
    FeeDetail.where('notes LIKE ?', "%#{pattern}%")
  end

  # Pagination support
  def self.page(page_number, per_page = 25)
    limit(per_page).offset((page_number - 1) * per_page)
  end

  # Validation and existence checks
  def self.exists?(conditions)
    FeeDetail.exists?(conditions)
  end

  def self.exists_by_id?(id)
    exists?(id: id)
  end

  def self.exists_by_external_fee_id?(external_fee_id)
    exists?(external_fee_id: external_fee_id)
  end

  # Statistics queries
  def self.status_counts
    {
      pending: pending.count,
      problematic: problematic.count,
      verified: verified.count
    }
  end

  def self.total_amount
    sum(:amount)
  end

  def self.total_amount_by_status(status)
    by_status(status).sum(:amount)
  end

  # Bulk operations
  def self.update_all(updates, conditions = nil)
    if conditions
      where(conditions).update_all(updates)
    else
      FeeDetail.update_all(updates)
    end
  end

  def self.delete_all(conditions = nil)
    if conditions
      where(conditions).delete_all
    else
      FeeDetail.delete_all
    end
  end

  # Performance-optimized queries
  def self.select_fields(fields = %i[id document_number fee_type amount verification_status fee_date])
    FeeDetail.select(fields)
  end

  def self.optimized_list
    select_fields.includes(:reimbursement)
  end

  # Error handling wrapper
  def self.safe_find(id)
    find(id)
  rescue ActiveRecord::RecordNotFound
    nil
  rescue StandardError => e
    Rails.logger.error "Error finding fee detail #{id}: #{e.message}"
    nil
  end

  def self.safe_find_by_external_fee_id(external_fee_id)
    find_by_external_fee_id(external_fee_id)
  rescue StandardError => e
    Rails.logger.error "Error finding fee detail by external fee ID #{external_fee_id}: #{e.message}"
    nil
  end

  # Complex queries for reporting
  def self.verification_summary
    group(:verification_status)
      .select(:verification_status, 'COUNT(*) as count', 'SUM(amount) as total_amount')
      .order(:verification_status)
  end

  def self.monthly_totals(year = Date.current.year)
    where('EXTRACT(YEAR FROM fee_date) = ?', year)
      .group('EXTRACT(MONTH FROM fee_date)')
      .select('EXTRACT(MONTH FROM fee_date) as month', 'SUM(amount) as total_amount', 'COUNT(*) as count')
      .order(:month)
  end

  def self.by_fee_type_totals
    group(:fee_type)
      .select(:fee_type, 'SUM(amount) as total_amount', 'COUNT(*) as count', 'AVG(amount) as average_amount')
      .order('SUM(amount) DESC')
  end
end
