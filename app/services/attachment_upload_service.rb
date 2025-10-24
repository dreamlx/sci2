# frozen_string_literal: true

# app/services/attachment_upload_service.rb
class AttachmentUploadService
  attr_reader :reimbursement, :params

  def initialize(reimbursement, params)
    @reimbursement = reimbursement
    @params = params
  end

  def upload
    fee_detail = build_fee_detail
    fee_detail.attachments.attach(params[:attachments]) if params[:attachments].present?

    if fee_detail.save
      { success: true, fee_detail: fee_detail }
    else
      { success: false, error: fee_detail.errors.full_messages.join(', ') }
    end
  rescue StandardError => e
    { success: false, error: e.message }
  end

  private

  def build_fee_detail
    FeeDetail.new(
      document_number: reimbursement.invoice_number,
      external_fee_id: generate_external_fee_id,
      fee_type: 'ATTACHMENT_EVIDENCE',
      amount: 0.00,
      verification_status: 'pending',
      notes: params[:notes]
    )
  end

  def generate_external_fee_id
    "ATTACHMENT_#{reimbursement.invoice_number}_#{Time.current.strftime('%Y%m%d%H%M%S')}_#{SecureRandom.hex(3).upcase}"
  end
end
