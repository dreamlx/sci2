class Reimbursement < ApplicationRecord
  # 关联
  has_many :express_receipt_work_orders, dependent: :destroy
  has_many :audit_work_orders, dependent: :destroy
  has_many :communication_work_orders, dependent: :destroy
  has_many :fee_details, foreign_key: 'document_number', primary_key: 'invoice_number'
  has_many :operation_histories, foreign_key: 'document_number', primary_key: 'invoice_number'
  
  # 验证
  validates :invoice_number, presence: true, uniqueness: true
  validates :document_name, presence: true
  validates :applicant, presence: true
  validates :applicant_id, presence: true
  
  # 回调
  after_create :create_audit_work_order_if_needed
  
  # 范围
  scope :electronic, -> { where(is_electronic: true) }
  scope :non_electronic, -> { where(is_electronic: false) }
  scope :completed, -> { where(is_complete: true) }
  scope :pending, -> { where(is_complete: false) }
  scope :received, -> { where(receipt_status: 'received') }
  scope :not_received, -> { where(receipt_status: 'pending') }
  
  # 方法
  def mark_as_received(receipt_date = Time.current)
    update(receipt_status: 'received', receipt_date: receipt_date)
  end
  
  def mark_as_complete
    update(is_complete: true, reimbursement_status: 'closed')
  end
  
  def create_audit_work_order(created_by = nil)
    audit_work_orders.create!(
      status: 'pending',
      created_by: created_by
    )
  end
  
  private
  
  def create_audit_work_order_if_needed
    # 如果是非电子发票且没有审核工单，则创建审核工单
    if !is_electronic && audit_work_orders.empty?
      create_audit_work_order
    end
  end
  
  # ActiveAdmin配置
  def self.ransackable_attributes(auth_object = nil)
    %w[id invoice_number document_name applicant applicant_id company department receipt_status reimbursement_status amount is_electronic is_complete created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[express_receipt_work_orders audit_work_orders communication_work_orders fee_details operation_histories]
  end
end