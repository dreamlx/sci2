# app/services/fee_detail_verification_service.rb
class FeeDetailVerificationService
  attr_reader :verifier

  def initialize(verifier)
    @verifier = verifier
  end

  def update_verification_status(fee_detail, new_status, comment = nil)
    return false unless ['problematic', 'verified'].include?(new_status)
    
    # 更新费用明细状态
    fee_detail.update(
      verification_status: new_status,
      verification_comment: comment,
      verified_at: (new_status == 'verified' ? Time.current : nil),
      verified_by: @verifier&.id
    )
  end
end