# app/models/operation_history.rb
class OperationHistory < ApplicationRecord
  # 关联
  belongs_to :reimbursement, foreign_key: 'document_number', primary_key: 'invoice_number', optional: true, inverse_of: :operation_histories
  
  # 验证
  validates :document_number, presence: true
  validates :operation_type, presence: true
  validates :operation_time, presence: true
  validates :operator, presence: true
  
  # 范围查询
  scope :by_document_number, ->(document_number) { where(document_number: document_number) }
  scope :by_operation_type, ->(operation_type) { where(operation_type: operation_type) }
  scope :by_date_range, ->(start_date, end_date) { where(operation_time: start_date..end_date) }
  
  # ActiveAdmin 配置
  def self.ransackable_attributes(auth_object = nil)
    %w[id document_number operation_type operation_time operator notes form_type operation_node created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[reimbursement]
  end
end