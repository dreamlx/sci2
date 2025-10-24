# app/models/operation_history.rb
class OperationHistory < ApplicationRecord
  # 关联
  belongs_to :reimbursement, foreign_key: 'document_number', primary_key: 'invoice_number', optional: true,
                             inverse_of: :operation_histories

  # 验证
  validates :document_number, presence: true
  validates :operation_type, presence: true
  validates :operation_time, presence: true
  validates :operator, presence: true

  # 回调：创建操作历史记录后更新报销单通知状态
  after_create :update_reimbursement_notification_status
  after_update :update_reimbursement_notification_status
  after_destroy :update_reimbursement_notification_status

  # 新增字段验证
  validates :applicant, presence: true, allow_blank: true
  validates :employee_id, presence: true, allow_blank: true
  validates :currency, inclusion: { in: %w[CNY USD EUR], allow_blank: true }
  validates :amount, numericality: { greater_than_or_equal_to: 0, allow_blank: true }

  # 范围查询
  scope :by_document_number, ->(document_number) { where(document_number: document_number) }
  scope :by_operation_type, ->(operation_type) { where(operation_type: operation_type) }
  scope :by_date_range, ->(start_date, end_date) { where(operation_time: start_date..end_date) }
  scope :by_applicant, ->(applicant) { where(applicant: applicant) }
  scope :by_employee_id, ->(employee_id) { where(employee_id: employee_id) }
  scope :by_employee_company, ->(company) { where(employee_company: company) }
  scope :by_employee_department, ->(department) { where(employee_department: department) }
  scope :by_submitter, ->(submitter) { where(submitter: submitter) }
  scope :by_currency, ->(currency) { where(currency: currency) }
  scope :by_amount_range, ->(min_amount, max_amount) { where(amount: min_amount..max_amount) }
  scope :by_created_date_range, ->(start_date, end_date) { where(created_date: start_date..end_date) }

  # ActiveAdmin 配置
  def self.ransackable_attributes(_auth_object = nil)
    %w[id document_number operation_type operation_time operator notes form_type operation_node
       applicant employee_id employee_company employee_department employee_department_path
       document_company document_department document_department_path submitter document_name
       currency amount created_date created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[reimbursement]
  end

  # 格式化方法
  def formatted_amount
    return '0' if amount.blank?

    amount.to_f
  end

  def formatted_operation_time
    operation_time&.strftime('%Y-%m-%d %H:%M:%S') || '0'
  end

  def formatted_created_date
    created_date&.strftime('%Y-%m-%d %H:%M:%S') || '0'
  end

  private

  def update_reimbursement_notification_status
    return unless reimbursement

    reimbursement.update_notification_status!
  end
end
