# app/models/reimbursement.rb
class Reimbursement < ApplicationRecord
  # 关联
  has_many :work_orders, dependent: :destroy # STI 基类关联
  
  # 便捷子类关联
  has_many :audit_work_orders, -> { where(type: 'AuditWorkOrder') }, class_name: 'AuditWorkOrder'
  has_many :communication_work_orders, -> { where(type: 'CommunicationWorkOrder') }, class_name: 'CommunicationWorkOrder'
  has_many :express_receipt_work_orders, -> { where(type: 'ExpressReceiptWorkOrder') }, class_name: 'ExpressReceiptWorkOrder'
  
  # 基于 invoice_number 外键的关联
  has_many :fee_details, foreign_key: 'document_number', primary_key: 'invoice_number', dependent: :destroy
  has_many :operation_histories, foreign_key: 'document_number', primary_key: 'invoice_number', dependent: :destroy

  # 验证
  validates :invoice_number, presence: true, uniqueness: true
  validates :document_name, presence: true
  validates :applicant, presence: true
  validates :applicant_id, presence: true
  validates :company, presence: true
  validates :department, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending processing approved rejected] }
  validates :receipt_status, inclusion: { in: %w[pending received] }
  validates :is_electronic, inclusion: { in: [true, false] }
  
  # 可选的其他验证
  validates :amount, presence: true, numericality: { greater_than: 0 }

  # 范围查询
  scope :electronic, -> { where(is_electronic: true) }
  scope :non_electronic, -> { where(is_electronic: false) }
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :closed, -> { where(external_status: 'closed') }
  
  # 可选的其他范围查询
  scope :recent, -> { order(created_at: :desc) }
  scope :by_applicant, ->(applicant) { where(applicant: applicant) }
  scope :by_department, ->(department) { where(department: department) }

  # 状态机
  state_machine :status, initial: :pending do
    state :pending
    state :processing
    state :approved
    state :rejected

    event :start_processing do
      transition [:pending, :approved, :rejected] => :processing
    end
    
    event :approve do
      transition [:pending, :processing] => :approved
    end
    
    event :reject do
      transition [:pending, :processing] => :rejected
    end
    
    # 状态转换后记录日志
    after_transition do |reimbursement, transition|
      Rails.logger.info "Reimbursement #{reimbursement.id} transitioned from #{transition.from} to #{transition.to} via #{transition.event}"
    end
  end

  # 状态检查方法
  def pending?
    status == 'pending'
  end
  
  def processing?
    status == 'processing'
  end
  
  def approved?
    status == 'approved'
  end
  
  def rejected?
    status == 'rejected'
  end

  # 业务方法
  def mark_as_received(receipt_date = Time.current)
    # 更新收单信息；如果需要，内部状态变更由状态机处理
    update(receipt_status: 'received', receipt_date: receipt_date)
    start_processing! if pending? # 仅当当前为 pending 时触发状态变更
  end
  
  def check_fee_details_status
    # 状态机转换条件的回调方法
    unless all_fee_details_verified?
      errors.add(:base, "尚有费用明细未核实，无法标记为等待完成")
      throw :halt # 如果条件不满足，阻止状态转换
    end
  end
  
  def all_fee_details_verified?
    # 检查所有关联的费用明细是否都是 'verified'
    # 确保 fee_details 已加载以避免在循环中出现 N+1 问题
    details = fee_details.loaded? ? fee_details : fee_details.reload
    details.present? && details.all? { |detail| detail.verification_status == 'verified' }
    # 替代方案: !fee_details.where.not(verification_status: 'verified').exists?
  end
  
  def update_status_based_on_fee_details!
    # 由 FeeDetail 回调调用的方法，可能触发状态变更
    mark_waiting_completion! if processing? && all_fee_details_verified?
  rescue StateMachines::InvalidTransition => e
    Rails.logger.error "Failed to update status for Reimbursement #{id}: #{e.message}"
  end

  # ActiveAdmin 配置
  def self.ransackable_attributes(auth_object = nil)
    # 包括导入字段和内部状态字段
    %w[id invoice_number document_name applicant applicant_id company department 
       receipt_status status external_status amount is_electronic 
       approval_date approver_name created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[work_orders audit_work_orders communication_work_orders 
       express_receipt_work_orders fee_details operation_histories]
  end
end