# app/models/fee_detail.rb
class FeeDetail < ApplicationRecord
  # 常量
  VERIFICATION_STATUS_PENDING = 'pending'
  VERIFICATION_STATUS_PROBLEMATIC = 'problematic'
  VERIFICATION_STATUS_VERIFIED = 'verified'
  VERIFICATION_STATUSES = [VERIFICATION_STATUS_PENDING, VERIFICATION_STATUS_PROBLEMATIC, VERIFICATION_STATUS_VERIFIED].freeze
  
  # 关联
  belongs_to :reimbursement, foreign_key: 'document_number', primary_key: 'invoice_number', optional: true, inverse_of: :fee_details
  has_many :fee_detail_selections, dependent: :destroy
  
  # 通用工单关联 - 需要自定义方法来获取所有类型的工单
  # 由于多态关联的限制，我们不能直接使用 has_many :through 获取所有类型的工单
  def work_orders
    # 使用原生SQL查询，因为多态关联在ActiveRecord中有限制
    work_order_ids = FeeDetailSelection.where(fee_detail_id: self.id).pluck(:work_order_id)
    WorkOrder.where(id: work_order_ids)
  end
  
  # 特定类型工单关联
  has_many :audit_work_orders,
           -> { where(type: 'AuditWorkOrder') },
           through: :fee_detail_selections,
           source: :work_order,
           source_type: 'AuditWorkOrder'
           
  has_many :communication_work_orders,
           -> { where(type: 'CommunicationWorkOrder') },
           through: :fee_detail_selections,
           source: :work_order,
           source_type: 'CommunicationWorkOrder'
  
  # 验证
  validates :document_number, presence: true
  validates :fee_type, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :verification_status, presence: true, inclusion: { in: VERIFICATION_STATUSES }
  
  # 范围查询
  scope :pending, -> { where(verification_status: VERIFICATION_STATUS_PENDING) }
  scope :problematic, -> { where(verification_status: VERIFICATION_STATUS_PROBLEMATIC) }
  scope :verified, -> { where(verification_status: VERIFICATION_STATUS_VERIFIED) }
  
  # 可选的其他范围查询
  scope :by_fee_type, ->(fee_type) { where(fee_type: fee_type) }
  scope :by_date_range, ->(start_date, end_date) { where(fee_date: start_date..end_date) }
  
  # 回调
  # 使用 after_commit 确保事务完成后再触发报销单状态更新
  after_commit :update_reimbursement_status, on: [:create, :update], if: :saved_change_to_verification_status?
  
  # 状态检查方法
  def verified?
    verification_status == VERIFICATION_STATUS_VERIFIED
  end
  
  def problematic?
    verification_status == VERIFICATION_STATUS_PROBLEMATIC
  end
  
  def pending?
    verification_status == VERIFICATION_STATUS_PENDING
  end
  
  # 业务方法
  def mark_as_verified(verifier = nil, comment = nil)
    Rails.logger.info "FeeDetail ##{id}: 开始标记为已验证，验证者: #{verifier&.email}"
    result = update(
      verification_status: VERIFICATION_STATUS_VERIFIED,
      notes: comment
    )
    if result
      Rails.logger.info "FeeDetail ##{id}: 成功标记为已验证"
    else
      Rails.logger.error "FeeDetail ##{id}: 标记为已验证失败: #{errors.full_messages.join(', ')}"
    end
    result
  end
  
  def mark_as_problematic(verifier = nil, comment = nil)
    Rails.logger.info "FeeDetail ##{id}: 开始标记为有问题，验证者: #{verifier&.email}"
    result = update(
      verification_status: VERIFICATION_STATUS_PROBLEMATIC,
      notes: comment
    )
    if result
      Rails.logger.info "FeeDetail ##{id}: 成功标记为有问题"
    else
      Rails.logger.error "FeeDetail ##{id}: 标记为有问题失败: #{errors.full_messages.join(', ')}"
    end
    result
  end
  
  # ActiveAdmin 配置
  def self.ransackable_attributes(auth_object = nil)
    %w[id document_number fee_type amount currency fee_date payment_method verification_status notes created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[reimbursement fee_detail_selections work_orders]
  end
  
  private
  
  def update_reimbursement_status
    return unless reimbursement.present?
    
    # 重新加载报销单以确保在提交后获取最新状态
    reimbursement.reload
    
    # 如果状态变更为已验证，检查报销单是否可以标记为等待完成
    if verification_status == VERIFICATION_STATUS_VERIFIED
      # 检查所有费用明细是否都已验证
      if reimbursement.all_fee_details_verified?
        reimbursement.update(status: 'waiting_completion')
      else
        reimbursement.update(status: 'processing') unless reimbursement.pending?
      end
    # 如果状态从已验证变为其他状态，确保报销单回到处理中
    elsif verification_status_before_last_save == VERIFICATION_STATUS_VERIFIED && reimbursement.waiting_completion?
      reimbursement.update(status: 'processing')
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Reimbursement not found for FeeDetail ##{id} during status update callback."
  end
end