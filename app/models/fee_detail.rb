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
  has_many :work_orders, through: :fee_detail_selections, source: :work_order, source_type: 'WorkOrder'
  
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
    update(verification_status: VERIFICATION_STATUS_VERIFIED)
  end
  
  def mark_as_problematic(verifier = nil, comment = nil)
    update(verification_status: VERIFICATION_STATUS_PROBLEMATIC)
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
      reimbursement.update_status_based_on_fee_details!
    # 如果状态从已验证变为其他状态，确保报销单回到处理中
    elsif verification_status_before_last_save == VERIFICATION_STATUS_VERIFIED
      reimbursement.start_processing! if reimbursement.waiting_completion?
    end
  # 处理状态转换过程中可能出现的错误
  rescue StateMachines::InvalidTransition => e
    Rails.logger.error "Error updating reimbursement status from FeeDetail ##{id}: #{e.message}"
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Reimbursement not found for FeeDetail ##{id} during status update callback."
  end
end