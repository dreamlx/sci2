# app/models/fee_detail.rb
class FeeDetail < ApplicationRecord
  # 常量
  VERIFICATION_STATUS_PENDING = 'pending'
  VERIFICATION_STATUS_PROBLEMATIC = 'problematic'
  VERIFICATION_STATUS_VERIFIED = 'verified'
  VERIFICATION_STATUSES = [VERIFICATION_STATUS_PENDING, VERIFICATION_STATUS_PROBLEMATIC, VERIFICATION_STATUS_VERIFIED].freeze
  
  # 关联
  belongs_to :reimbursement, foreign_key: 'document_number', primary_key: 'invoice_number', optional: true, inverse_of: :fee_details
  
  
  # 通用工单关联 - 需要自定义方法来获取所有类型的工单
  # 由于多态关联的限制，我们不能直接使用 has_many :through 获取所有类型的工单

  
  # 特定类型工单关联

  
           # 验证
  validates :document_number, presence: true
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
  
  # 新的多对多关联
  has_many :work_order_fee_details, dependent: :destroy
  has_many :work_orders,
           through: :work_order_fee_details,
           source: :work_order,
           source_type: 'WorkOrder'

  # 如果需要根据类型快速获取工单，可以添加如下方法：
  # def audit_work_orders
  #   work_orders.where(type: 'AuditWorkOrder')
  # end
  #
  # def communication_work_orders
  #   work_orders.where(type: 'CommunicationWorkOrder')
  # end

  # ActiveAdmin 配置
  def self.ransackable_attributes(auth_object = nil)
    %w[id document_number fee_type amount currency fee_date payment_method verification_status notes created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[reimbursement work_orders work_order_fee_details] # 添加了新的关联
  end
  
  def summary_for_selection
    "ID: #{id} - #{fee_type} (#{amount} #{currency})"
  end
  
  private
  
  def update_reimbursement_status
    return unless reimbursement.present?
    
    reimbursement.reload
    
    # If verification_status changed to VERIFIED
    if verification_status == VERIFICATION_STATUS_VERIFIED
      # If all fee details for the reimbursement are now verified
      if reimbursement.all_fee_details_verified?
        # What should happen to reimbursement status? 
        # Previously, it tried to set to 'waiting_completion'.
        # For now, let's assume it remains 'processing' or is handled by WorkOrder logic.
        # No direct status update here to prevent errors, unless a new valid state is defined.
        Rails.logger.info "FeeDetail ##{id}: All fee details for Reimbursement ##{reimbursement.id} are now verified."
        # reimbursement.update(status: 'new_approved_state') # If there was a new target state
      else
        # If some details are verified but not all, ensure reimbursement is at least processing if it was pending.
        reimbursement.update(status: 'processing') if reimbursement.pending?
      end
    # If verification_status changed FROM VERIFIED to something else
    elsif verification_status_before_last_save == VERIFICATION_STATUS_VERIFIED
      # If a fee detail that was verified is no longer verified, 
      # reimbursement should be in 'processing' if it wasn't already pending.
      # We need to know what state it would have been in if waiting_completion was valid.
      # Assuming it implies it was effectively 'processing' or a precursor to 'closed'.
      # If it's not pending, ensure it is processing.
      if reimbursement.status != 'pending' && reimbursement.status != 'processing'
         # This case means it might have been 'closed' or some other state and a verified detail became unverified.
         # This typically implies it should go back to 'processing'.
         reimbursement.update(status: 'processing')
         Rails.logger.info "FeeDetail ##{id}: Reimbursement ##{reimbursement.id} status moved to 'processing' because a verified detail was un-verified."
      elsif reimbursement.pending?
        # If it's pending, it should stay pending or move to processing by other logic, not revert from a higher state.
      else 
        # It's already processing, no change needed in this specific path.
      end
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Reimbursement not found for FeeDetail ##{id} during status update callback."
  rescue => e # Catch other potential errors like NoMethodError if status methods are missing
    Rails.logger.error "Error in FeeDetail#update_reimbursement_status for FeeDetail ##{id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end