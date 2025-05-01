# app/models/audit_work_order.rb
class AuditWorkOrder < WorkOrder
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
      transition [:pending, :processing] => :approved
    end

    event :reject do
      transition [:pending, :processing] => :rejected
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
    
    # 确保使用正确的work_order_type
    FeeDetailSelection.find_or_create_by!(
      fee_detail: fee_detail,
      work_order_id: self.id,
      work_order_type: 'AuditWorkOrder'
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
    Rails.logger.info "Processing fee detail selections for AuditWorkOrder ##{id}: #{@fee_detail_ids_to_select.inspect}"
    
    # 确保我们有关联的报销单
    if reimbursement.nil?
      Rails.logger.error "AuditWorkOrder ##{id} has no associated reimbursement"
      return
    end
    
    # 查找费用明细
    fee_details = FeeDetail.where(id: @fee_detail_ids_to_select, document_number: reimbursement.invoice_number)
    Rails.logger.info "Found #{fee_details.count} fee details for AuditWorkOrder ##{id}"
    
    # 创建费用明细选择
    fee_details.each do |fee_detail|
      # 显式指定work_order_type为'AuditWorkOrder'
      selection = FeeDetailSelection.find_or_create_by(
        fee_detail: fee_detail,
        work_order_id: self.id,
        work_order_type: 'AuditWorkOrder'
      )
      selection.update(verification_status: fee_detail.verification_status)
      Rails.logger.info "Created/updated fee detail selection for fee detail ##{fee_detail.id} with status #{selection.verification_status}"
    end
  end

  # ActiveAdmin 支持
  # 覆盖基类的 ransackable 方法
  def self.subclass_ransackable_attributes
    # 继承的通用字段 + Req 6/7 字段 + 特定字段
    %w[audit_result audit_comment audit_date vat_verified problem_type problem_description remark processing_opinion]
  end

  def self.subclass_ransackable_associations
    [] # 移除与 CommunicationWorkOrder 的关联
  end
  
  # 覆盖基类的 ransackable_associations 方法
  def self.ransackable_associations(auth_object = nil)
    %w[reimbursement creator] # 允许搜索关联的报销单和创建者
  end
  
  # 单元测试将在下面步骤中添加
end