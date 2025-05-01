# app/services/fee_detail_verification_service.rb
class FeeDetailVerificationService
  def initialize(current_admin_user)
    @current_admin_user = current_admin_user
    Current.admin_user = current_admin_user # 设置 Current 上下文
  end
  
  # 更新单个费用明细的验证状态
  def update_verification_status(fee_detail, status, comment = nil)
    Rails.logger.info "FeeDetailVerificationService: 开始更新费用明细 ##{fee_detail.id} 的验证状态为 #{status}"
    
    # 验证状态有效性 - 同时支持字符串和常量
    valid_statuses = ['pending', 'problematic', 'verified']
    unless valid_statuses.include?(status) || FeeDetail::VERIFICATION_STATUSES.include?(status)
      fee_detail.errors.add(:verification_status, "无效的验证状态: #{status}")
      Rails.logger.error "FeeDetailVerificationService: 无效的验证状态: #{status}"
      return false
    end
    
    # 检查报销单是否已关闭
    if fee_detail.reimbursement&.closed?
      fee_detail.errors.add(:base, "报销单已关闭，无法更新费用明细验证状态")
      Rails.logger.error "FeeDetailVerificationService: 报销单已关闭，无法更新费用明细验证状态"
      return false
    end
    
    # 标准化状态值
    normalized_status = case status
                        when 'verified', FeeDetail::VERIFICATION_STATUS_VERIFIED
                          FeeDetail::VERIFICATION_STATUS_VERIFIED
                        when 'problematic', FeeDetail::VERIFICATION_STATUS_PROBLEMATIC
                          FeeDetail::VERIFICATION_STATUS_PROBLEMATIC
                        when 'pending', FeeDetail::VERIFICATION_STATUS_PENDING
                          FeeDetail::VERIFICATION_STATUS_PENDING
                        else
                          status
                        end
    
    Rails.logger.info "FeeDetailVerificationService: 标准化状态值为 #{normalized_status}"
    
    # 更新费用明细验证状态
    Rails.logger.info "FeeDetailVerificationService: 直接更新 verification_status 为 #{normalized_status}"
    
    # 直接更新 verification_status，如果有 comment 则更新 notes
    update_params = { verification_status: normalized_status }
    update_params[:notes] = comment if comment.present?
    
    result = fee_detail.update(update_params)
    
    Rails.logger.info "FeeDetailVerificationService: 更新费用明细验证状态结果: #{result}"
    
    # 更新关联的费用明细选择记录
    if result
      Rails.logger.info "FeeDetailVerificationService: 开始更新关联的费用明细选择记录"
      update_fee_detail_selections(fee_detail, normalized_status, comment)
    else
      Rails.logger.error "FeeDetailVerificationService: 更新费用明细验证状态失败，不更新关联的费用明细选择记录"
      Rails.logger.error "FeeDetailVerificationService: 错误信息: #{fee_detail.errors.full_messages.join(', ')}"
    end

    # 触发报销单状态更新检查
    if fee_detail.reimbursement && result
      Rails.logger.info "FeeDetailVerificationService: 触发报销单状态更新检查"
      fee_detail.reimbursement.update_status_based_on_fee_details!
    end

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
    Rails.logger.info "FeeDetailVerificationService: 开始更新费用明细 ##{fee_detail.id} 的关联选择记录"
    
    # 查找所有关联的费用明细选择记录
    selections = fee_detail.fee_detail_selections
    Rails.logger.info "FeeDetailVerificationService: 找到 #{selections.count} 个关联的费用明细选择记录"
    
    selections.each do |selection|
      Rails.logger.info "FeeDetailVerificationService: 更新费用明细选择 ##{selection.id}，关联工单 ##{selection.work_order_id} (#{selection.work_order_type})"
      
      # 只更新评论、验证者和验证时间，不再更新状态
      result = selection.update(
        verification_comment: comment,
        verifier: @current_admin_user,
        verified_at: Time.current
      )
      
      if result
        Rails.logger.info "FeeDetailVerificationService: 成功更新费用明细选择 ##{selection.id} 的评论和验证信息"
      else
        Rails.logger.error "FeeDetailVerificationService: 更新费用明细选择 ##{selection.id} 失败: #{selection.errors.full_messages.join(', ')}"
      end
    end
  rescue => e
    Rails.logger.error "FeeDetailVerificationService: 更新关联的费用明细选择记录时出错: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end