# app/models/audit_work_order.rb
class AuditWorkOrder < WorkOrder
  # 关联 (如上)
  has_many :communication_work_orders, foreign_key: 'audit_work_order_id', dependent: :nullify, inverse_of: :audit_work_order

  # 验证 (如上)
  validates :status, inclusion: { in: %w[pending processing approved rejected] }
  validates :audit_result, presence: true, if: -> { approved? || rejected? }

  # 可选的其他验证
  validates :problem_type, presence: true, if: -> { rejected? }

  # 状态机
  state_machine :status, initial: :pending do
    event :start_processing do
      transition :pending => :processing
    end

    event :approve do
      transition :processing => :approved
    end

    event :reject do
      transition :processing => :rejected
    end

    # 开始处理时将费用明细标记为有问题
    after_transition on: :start_processing do |work_order, transition|
      work_order.update_associated_fee_details_status('problematic')
    end

    # 审核通过前设置审核结果和日期
    before_transition on: :approve do |work_order, transition|
      work_order.audit_result = 'approved'
      work_order.audit_date = Time.current
    end

    # 审核通过时将费用明细标记为已验证
    after_transition on: :approve do |work_order, transition|
      work_order.update_associated_fee_details_status('verified')
    end

    # 审核拒绝前设置审核结果和日期
    before_transition on: :reject do |work_order, transition|
      work_order.audit_result = 'rejected'
      work_order.audit_date = Time.current
    end

    # 审核拒绝时将费用明细标记为有问题
    after_transition on: :reject do |work_order, transition|
      work_order.update_associated_fee_details_status('problematic')
    end
  end

  # 状态检查方法和作用域
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  
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

  # 费用明细选择方法 (如上)
  def select_fee_detail(fee_detail)
    return nil unless fee_detail.document_number == self.reimbursement.invoice_number
    fee_detail_selections.find_or_create_by!(fee_detail: fee_detail) do |selection|
      selection.verification_status = fee_detail.verification_status # 创建时同步状态
    end
  end

  def select_fee_details(fee_detail_ids)
    fee_details_to_select = FeeDetail.where(id: fee_detail_ids, document_number: self.reimbursement.invoice_number)
    fee_details_to_select.each { |fd| select_fee_detail(fd) }
  end

  # ActiveAdmin 支持
  # 覆盖基类的 ransackable 方法
  def self.subclass_ransackable_attributes
    # 继承的通用字段 + Req 6/7 字段 + 特定字段
    %w[audit_result audit_comment audit_date vat_verified problem_type problem_description remark processing_opinion]
  end

  def self.subclass_ransackable_associations
    %w[communication_work_orders]
  end

  # 更新关联费用明细的状态
  def update_associated_fee_details_status(new_status)
    valid_statuses = ['problematic', 'verified']
    return unless valid_statuses.include?(new_status)
    
    # 更新所有关联的费用明细选择的验证状态
    fee_detail_selections.each do |selection|
      selection.update(verification_status: new_status)
    end
  end
  
  # 单元测试将在下面步骤中添加
end