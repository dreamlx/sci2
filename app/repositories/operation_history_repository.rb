# frozen_string_literal: true

# Repository for OperationHistory data access
# Provides a clean interface for database operations and query logic
class OperationHistoryRepository
  # Find operations
  def self.find(id)
    OperationHistory.find(id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def self.find_by_id(id)
    OperationHistory.find_by(id: id)
  end

  # Batch operations
  def self.find_by_ids(operation_history_ids)
    OperationHistory.where(id: operation_history_ids)
  end

  # Query operations
  def self.where(conditions)
    OperationHistory.where(conditions)
  end

  def self.where_not(conditions)
    OperationHistory.where.not(conditions)
  end

  def self.where_in(field, values)
    OperationHistory.where(field => values)
  end

  def self.where_not_in(field, values)
    OperationHistory.where.not(field => values)
  end

  # Delegate aggregate methods to OperationHistory
  def self.sum(field)
    OperationHistory.sum(field)
  end

  def self.group(field)
    OperationHistory.group(field)
  end

  def self.select(fields)
    OperationHistory.select(fields)
  end

  # Ordering and limiting
  def self.order(field)
    OperationHistory.order(field)
  end

  def self.limit(count)
    OperationHistory.limit(count)
  end

  def self.offset(count)
    OperationHistory.offset(count)
  end

  # Join operations
  def self.joins(associations)
    OperationHistory.joins(associations)
  end

  def self.includes(associations)
    OperationHistory.includes(associations)
  end

  # Pluck operations
  def self.pluck(field)
    OperationHistory.pluck(field)
  end

  def self.distinct_pluck(field)
    OperationHistory.distinct.pluck(field)
  end

  # Count operations
  def self.count
    OperationHistory.count
  end

  def self.where_count(conditions)
    OperationHistory.where(conditions).count
  end

  # Document-based queries
  def self.by_document_number(document_number)
    OperationHistory.where(document_number: document_number)
  end

  def self.by_document_numbers(document_numbers)
    OperationHistory.where(document_number: document_numbers)
  end

  def self.for_reimbursement(reimbursement)
    by_document_number(reimbursement.invoice_number)
  end

  def self.for_reimbursements(reimbursements)
    document_numbers = reimbursements.map(&:invoice_number)
    by_document_numbers(document_numbers)
  end

  # Operation type queries
  def self.by_operation_type(operation_type)
    OperationHistory.where(operation_type: operation_type)
  end

  def self.by_operation_types(operation_types)
    OperationHistory.where(operation_type: operation_types)
  end

  # Date-based queries
  def self.by_date_range(start_date, end_date)
    OperationHistory.where(operation_time: start_date..end_date)
  end

  def self.by_created_date_range(start_date, end_date)
    OperationHistory.where(created_date: start_date..end_date)
  end

  def self.created_today
    by_date_range(Date.current.beginning_of_day, Date.current.end_of_day)
  end

  def self.created_this_month
    by_date_range(Date.current.beginning_of_month, Date.current.end_of_month)
  end

  # Employee-based queries
  def self.by_applicant(applicant)
    OperationHistory.where(applicant: applicant)
  end

  def self.by_employee_id(employee_id)
    OperationHistory.where(employee_id: employee_id)
  end

  def self.by_employee_company(company)
    OperationHistory.where(employee_company: company)
  end

  def self.by_employee_department(department)
    OperationHistory.where(employee_department: department)
  end

  def self.by_submitter(submitter)
    OperationHistory.where(submitter: submitter)
  end

  # Document metadata queries
  def self.by_document_company(company)
    OperationHistory.where(document_company: company)
  end

  def self.by_document_department(department)
    OperationHistory.where(document_department: department)
  end

  # Financial queries
  def self.by_currency(currency)
    OperationHistory.where(currency: currency)
  end

  def self.by_amount_range(min_amount, max_amount)
    OperationHistory.where(amount: min_amount..max_amount)
  end

  def self.with_amount
    OperationHistory.where.not(amount: nil)
  end

  def self.total_amount
    sum(:amount)
  end

  def self.total_amount_by_currency(currency)
    by_currency(currency).sum(:amount)
  end

  # Search functionality
  def self.search_by_operator(pattern)
    OperationHistory.where('operator LIKE ?', "%#{pattern}%")
  end

  def self.search_by_applicant(pattern)
    OperationHistory.where('applicant LIKE ?', "%#{pattern}%")
  end

  def self.search_by_notes(pattern)
    OperationHistory.where('notes LIKE ?', "%#{pattern}%")
  end

  # Pagination support
  def self.page(page_number, per_page = 25)
    limit(per_page).offset((page_number - 1) * per_page)
  end

  # Validation and existence checks
  def self.exists?(conditions)
    OperationHistory.exists?(conditions)
  end

  def self.exists_by_id?(id)
    exists?(id: id)
  end

  def self.exists_by_document_number?(document_number)
    exists?(document_number: document_number)
  end

  # Statistics queries
  def self.operation_type_counts
    group(:operation_type).count
  end

  def self.currency_counts
    group(:currency).count
  end

  def self.company_counts
    group(:employee_company).count
  end

  def self.department_counts
    group(:employee_department).count
  end

  # Recent operations
  def self.recent(limit_count = 10)
    order(operation_time: :desc).limit(limit_count)
  end

  def self.latest_for_document(document_number, limit_count = 5)
    by_document_number(document_number)
      .order(operation_time: :desc)
      .limit(limit_count)
  end

  # Performance-optimized queries
  def self.select_fields(fields = %i[id document_number operation_type operation_time operator])
    OperationHistory.select(fields)
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
    Rails.logger.error "Error finding operation history #{id}: #{e.message}"
    nil
  end

  def self.safe_find_by_document_number(document_number)
    by_document_number(document_number).first
  rescue StandardError => e
    Rails.logger.error "Error finding operation history by document number #{document_number}: #{e.message}"
    nil
  end

  # Complex queries for reporting
  def self.operation_summary_by_date(start_date, end_date)
    by_date_range(start_date, end_date)
      .group(:operation_type, :currency)
      .select(:operation_type, :currency, 'COUNT(*) as count', 'SUM(amount) as total_amount')
      .order(:operation_type, :currency)
  end

  def self.monthly_operation_summary(year = Date.current.year)
    where('EXTRACT(YEAR FROM operation_time) = ?', year)
      .group('EXTRACT(MONTH FROM operation_time)', :operation_type)
      .select('EXTRACT(MONTH FROM operation_time) as month', :operation_type, 'COUNT(*) as count')
      .order(:month, :operation_type)
  end

  def self.top_operators(limit_count = 10)
    group(:operator)
      .select(:operator, 'COUNT(*) as operation_count')
      .order('operation_count DESC')
      .limit(limit_count)
  end

  def self.financial_summary_by_currency
    group(:currency)
      .select(:currency, 'COUNT(*) as count', 'SUM(amount) as total_amount', 'AVG(amount) as average_amount')
      .order('total_amount DESC')
  end
end
