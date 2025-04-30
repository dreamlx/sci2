# app/models/communication_work_order.rb
class CommunicationWorkOrder < WorkOrder
  # 关联
  has_many :communication_records, foreign_key: 'communication_work_order_id', dependent: :destroy, inverse_of: :communication_work_order
  
  # 验证
  validates :status, inclusion: { in: %w[pending processing approved rejected] }
  
  # 可选的其他验证
  validates :resolution_summary, presence: true, if: -> { approved? || rejected? }
  validates :problem_type, presence: true, if: -> { rejected? }
  
  # 状态机
  state_machine :status, initial: :pending do
    event :start_processing do
      transition :pending => :processing
    end
    
    event :approve do
      transition [:pending, :processing] => :approved
    end
    
    event :reject do
      transition [:pending, :processing] => :rejected
    end
    
    # 开始处理时将费用明细标记为有问题
    after_transition on: :start_processing do |work_order, transition|
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
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :needs_communication, -> { where(needs_communication: true) }
  
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
  
  # 费用明细选择方法
  def select_fee_detail(fee_detail)
    return nil unless fee_detail.document_number == self.reimbursement.invoice_number
    
    # 确保使用正确的work_order_type
    FeeDetailSelection.find_or_create_by!(
      fee_detail: fee_detail,
      work_order_id: self.id,
      work_order_type: 'CommunicationWorkOrder'
    ) do |selection|
      selection.verification_status = fee_detail.verification_status # 创建时同步状态
    end
  end
  
  def select_fee_details(fee_detail_ids)
    return [] if fee_detail_ids.blank? || !persisted?
    
    # 直接处理费用明细选择
    fee_details_to_select = FeeDetail.where(id: fee_detail_ids, document_number: self.reimbursement.invoice_number)
    selections = []
    
    fee_details_to_select.each do |fd|
      selection = select_fee_detail(fd)
      selections << selection if selection
    end
    
    selections
  end
  
  # 保留回调以兼容现有代码
  after_create :process_fee_detail_selections
  
  def process_fee_detail_selections
    # 使用@fee_detail_ids_to_select，如果存在
    return unless @fee_detail_ids_to_select.present?
    
    # 添加日志以便调试
    Rails.logger.info "Processing fee detail selections for CommunicationWorkOrder ##{id}: #{@fee_detail_ids_to_select.inspect}"
    
    # 确保我们有关联的报销单
    if reimbursement.nil?
      Rails.logger.error "CommunicationWorkOrder ##{id} has no associated reimbursement"
      return
    end
    
    # 查找费用明细
    fee_details = FeeDetail.where(id: @fee_detail_ids_to_select, document_number: reimbursement.invoice_number)
    Rails.logger.info "Found #{fee_details.count} fee details for CommunicationWorkOrder ##{id}"
    
    # 创建费用明细选择
    fee_details.each do |fee_detail|
      selection = fee_detail_selections.find_or_create_by(fee_detail: fee_detail)
      selection.update(verification_status: fee_detail.verification_status)
      Rails.logger.info "Created/updated fee detail selection for fee detail ##{fee_detail.id} with status #{selection.verification_status}"
    end
  end
  
  # 沟通记录方法
  def add_communication_record(params)
    # 如果没有提供 communicator_name，则使用当前用户的 email
    params[:communicator_name] ||= Current.admin_user&.email if Current.admin_user.present?
    
    # 确保正确设置外键
    communication_records.create(params.merge(communication_work_order_id: self.id))
  end
  
  # 方法来设置和取消 needs_communication 标志
  def needs_communication?
    self.needs_communication == true
  end
  
  def mark_needs_communication!
    update(needs_communication: true)
  end
  
  def unmark_needs_communication!
    update(needs_communication: false)
  end
  
  # 覆盖基类的 ransackable 方法
  def self.subclass_ransackable_attributes
    # 继承的通用字段 + Req 6/7 字段 + 特定字段
    %w[communication_method initiator_role resolution_summary problem_type problem_description remark processing_opinion needs_communication]
  end
  
  def self.subclass_ransackable_associations
    %w[communication_records]
  end
end