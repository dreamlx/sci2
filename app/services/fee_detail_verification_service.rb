class FeeDetailVerificationService
  attr_reader :admin_user

  def initialize(admin_user)
    @admin_user = admin_user
  end

  def update_verification_status(fee_detail, status, comment = nil)
    return false unless fee_detail.verifiable?

    fee_detail.update_verification_status(status, comment, @admin_user.id)
    notify_audit_team(fee_detail)
  end

  def verify_fee_details(fee_detail_ids, status, comment = nil)
    fee_details = FeeDetail.where(id: fee_detail_ids)

    fee_details.each do |fee_detail|
      update_verification_status(fee_detail, status, comment) if fee_detail.verifiable?
    end

    fee_details
  end

  def verify_fee_detail_in_work_order(work_order, fee_detail_id, status, comment = nil)
    fee_detail = FeeDetail.find_by(id: fee_detail_id, reimbursement_id: work_order.reimbursement_id)

    return false unless fee_detail && fee_detail.verifiable?

    fee_detail.update_verification_status(status, comment, @admin_user.id)
    notify_audit_team(fee_detail)
  end

  def get_verification_history(fee_detail)
    FeeDetailSelection.where(fee_detail_id: fee_detail.id).order(:verified_at => :desc)
  end

  def get_fee_details_by_status(status, reimbursement_id = nil)
    if reimbursement_id
      FeeDetail.where(reimbursement_id: reimbursement_id, verification_status: status)
    else
      FeeDetail.where(verification_status: status)
    end
  end

  private

  def notify_audit_team(fee_detail)
    # This method can be extended to integrate with a notification service
    Rails.logger.info "Fee detail #{fee_detail.id} verification status changed by #{@admin_user.email}"
  end
end