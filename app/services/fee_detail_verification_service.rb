# app/services/fee_detail_verification_service.rb
class FeeDetailVerificationService
  def initialize(current_admin_user)
    @current_admin_user = current_admin_user
    Current.admin_user = current_admin_user # 设置 Current 上下文
  end
  
  # 更新单个费用明细的验证状态
  def update_verification_status(fee_detail, status, comment = nil)
    # 验证状态有效性
    unless FeeDetail::VERIFICATION_STATUSES.include?(status)
      fee_detail.errors.add(:verification_status, "无效的验证状态: #{status}")
      return false
    end
    
    # 检查报销单是否已关闭
    if fee_detail.reimbursement&.closed?
      fee_detail.errors.add(:base, "报销单已关闭，无法更新费用明细验证状态")
      return false
    end
    
    # 更新费用明细验证状态
    result = case status
             when FeeDetail::VERIFICATION_STATUS_VERIFIED
               fee_detail.mark_as_verified(@current_admin_user, comment)
             when FeeDetail::VERIFICATION_STATUS_PROBLEMATIC
               fee_detail.mark_as_problematic(@current_admin_user, comment)
             else
               fee_detail.update(verification_status: status)
             end
    
    # 更新关联的费用明细选择记录
    update_fee_detail_selections(fee_detail, status, comment) if result
    
    result
  end
  
  # 批量更新费用明细验证状态
  def batch_update_verification_status(fee_details, status, comment = nil)
    return false unless FeeDetail::VERIFICATION_STATUSES.include?(status)
    
    results = []
    ActiveRecord::Base.transaction do
      fee_details.each do |fee_detail|
        results << update_verification_status(fee_detail, status, comment)
      end
      
      # 如果有任何一个更新失败，回滚事务
      raise ActiveRecord::Rollback if results.include?(false)
    end
    
    !results.include?(false)
  end
  
  private
  
  # 更新关联的费用明细选择记录
  def update_fee_detail_selections(fee_detail, status, comment = nil)
    # 查找所有关联的费用明细选择记录
    fee_detail.fee_detail_selections.each do |selection|
      selection.update(
        verification_status: status,
        verification_comment: comment,
        verified_by: @current_admin_user.id,
        verified_at: Time.current
      )
    end
  end
end