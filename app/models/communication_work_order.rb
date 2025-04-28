# app/models/communication_work_order.rb
class CommunicationWorkOrder < WorkOrder
  # 关联
  belongs_to :audit_work_order, class_name: 'AuditWorkOrder', foreign_key: 'audit_work_order_id', optional: false
  has_many :communication_records, foreign_key: 'communication_work_order_id', dependent: :destroy, inverse_of: :communication_work_order
  
  # 验证
  validates :status, inclusion: { in: %w[pending processing needs_communication approved rejected] }
  validates :audit_work_order_id, presence: true
  
  # 可选的其他验证
  validates :resolution_summary, presence: true, if: -> { approved? || rejected? }
  validates :problem_type, presence: true, if: -> { rejected? }
  
  # 状态机
  state_machine :status, initial: :pending do
    event :start_processing do
      transition :pending => :processing
    end
    
    event :mark_needs_communication do
      transition :pending => :needs_communication
    end
    
    event :approve do
      transition [:processing, :needs_communication] => :approved
    end
    
    event :reject do
      transition [:processing, :needs_communication] => :rejected
    end
    
    # 开始处理时将费用明细标记为有问题
    after_transition on: :start_processing do |work_order, transition|
      work_order.update_associated_fee_details_status('problematic')
    end
    
    # 标记需要沟通时将费用明细标记为有问题
    after_transition on: :mark_needs_communication do |work_order, transition|
      work_order.update_associated_fee_details_status('problematic')
    end
    
    # 沟通通过时将费用明细标记为已验证
    after_transition on: :approve do |work_order, transition|
      work_order.update_associated_fee_details_status('verified')
    end
    
    # 沟通拒绝时将费用明细标记为有问题
    after_transition on: :reject do |work_order, transition|
      work_order.update_associated_fee_details_status('problematic')
    end
  end
  
  # 状态检查方法和作用域
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :needs_communication, -> { where(status: 'needs_communication') }
  
  def pending?
    status == 'pending'
  end
  
  def processing?
    status == 'processing'
  end
  
  def needs_communication?
    status == 'needs_communication'
  end
  
  def approved?
    status == 'approved'
  end
  
  def rejected?
    status == 'rejected'
  end
  
  # 费用明细选择方法
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
  
  # 沟通记录方法
  def add_communication_record(params)
    # 确保正确设置外键
    communication_records.create(params.merge(communication_work_order_id: self.id))
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
  
  # 覆盖基类的 ransackable 方法
  def self.subclass_ransackable_attributes
    # 继承的通用字段 + Req 6/7 字段 + 特定字段
    %w[communication_method initiator_role resolution_summary audit_work_order_id problem_type problem_description remark processing_opinion]
  end
  
  def self.subclass_ransackable_associations
    %w[audit_work_order communication_records]
  end
end