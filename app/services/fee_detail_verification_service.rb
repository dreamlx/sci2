# app/services/fee_detail_verification_service.rb
class FeeDetailVerificationService
  def initialize(current_admin_user)
    @current_admin_user = current_admin_user
    Current.admin_user = current_admin_user # 设置 Current 上下文
  end

  # 更新单个费用明细的验证状态
  def update_verification_status(fee_detail, status, comment = nil)
    Rails.logger.info "[FeeDetailVerificationService] Updating FeeDetail ##{fee_detail.id} to status: #{status}"

    # 确保 status 是模型中定义的常量之一
    normalized_status = normalize_status(status)
    unless normalized_status
      fee_detail.errors.add(:verification_status, "无效的验证状态: #{status}")
      Rails.logger.error "[FeeDetailVerificationService] Invalid verification status: #{status} for FeeDetail ##{fee_detail.id}"
      return false
    end

    if fee_detail.reimbursement&.closed?
      fee_detail.errors.add(:base, '报销单已关闭，无法更新费用明细验证状态')
      Rails.logger.warn "[FeeDetailVerificationService] Reimbursement closed for FeeDetail ##{fee_detail.id}. Cannot update status."
      return false
    end

    Rails.logger.info "[FeeDetailVerificationService] Normalized status to: #{normalized_status} for FeeDetail ##{fee_detail.id}"

    update_params = { verification_status: normalized_status }
    update_params[:notes] = comment if comment.present? # 只有当 comment 非空时才更新 notes

    result = fee_detail.update(update_params)

    if result
      Rails.logger.info "[FeeDetailVerificationService] Successfully updated FeeDetail ##{fee_detail.id}."
      # 触发报销单状态更新检查 (这个回调在 FeeDetail 模型中定义，并且会在 verification_status 变化时触发)
      # 这里显式调用是为了确保在 Service 层操作后，如果模型回调没有覆盖所有场景或被跳过，状态也能更新。
      # 不过，FeeDetail 的 after_commit :update_reimbursement_status 应该已经处理了。
      # 可以考虑是否冗余，但保留它通常是安全的，除非有性能问题。
      if fee_detail.reimbursement&.persisted? # Ensure reimbursement exists and is persisted
        fee_detail.reimbursement.reload.update_status_based_on_fee_details!
        Rails.logger.info "[FeeDetailVerificationService] Triggered reimbursement status update for Reimbursement ##{fee_detail.reimbursement.id}."
      end
    else
      Rails.logger.error "[FeeDetailVerificationService] Failed to update FeeDetail ##{fee_detail.id}: #{fee_detail.errors.full_messages.join(', ')}"
    end

    result
  end

  # 批量更新费用明细验证状态
  def batch_update_verification_status(fee_details, status, comment = nil)
    normalized_status = normalize_status(status)
    unless normalized_status
      Rails.logger.error "[FeeDetailVerificationService] Batch update called with invalid status: #{status}"
      return false # 或者抛出参数错误
    end

    # 如果 fee_details 是一个 ActiveRecord::Relation, to_a 不是必须的，但如果它是数组则无害
    return true if fee_details.to_a.empty? # 如果没有费用明细需要处理，则认为操作成功

    all_succeeded = true
    ActiveRecord::Base.transaction do
      fee_details.each do |fee_detail|
        unless update_verification_status(fee_detail, normalized_status, comment)
          all_succeeded = false
          raise ActiveRecord::Rollback # 如果有任何一个更新失败，回滚整个事务
        end
      end
    end

    all_succeeded
  end

  private

  def normalize_status(status_param)
    # 将传入的 status (可能是字符串或符号) 标准化为模型中定义的常量
    # FeeDetail::VERIFICATION_STATUSES 已经是 [PENDING, PROBLEMATIC, VERIFIED]
    status_string = status_param.to_s.downcase # 转为小写字符串以匹配常量值
    return status_string if FeeDetail::VERIFICATION_STATUSES.include?(status_string)

    # 为了兼容旧的传入方式，也检查一下是否直接等于常量（虽然常量本身就是字符串）
    return status_param if FeeDetail::VERIFICATION_STATUSES.include?(status_param)

    nil # 如果无法匹配任何有效状态，返回 nil
  end
end
