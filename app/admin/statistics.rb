ActiveAdmin.register_page "Statistics" do
  menu false
  controller do
    def reimbursement_status_counts
      counts = {
        pending: Reimbursement.where(status: 'pending').count,
        processing: Reimbursement.where(status: 'processing').count,
        waiting_completion: Reimbursement.where(status: 'waiting_completion').count,
        closed: Reimbursement.where(status: 'closed').count
      }

      render json: counts
    end

    def work_order_status_counts
      counts = {
        audit: {
          pending: AuditWorkOrder.where(status: 'pending').count,
          processing: AuditWorkOrder.where(status: 'processing').count,
          approved: AuditWorkOrder.where(status: 'approved').count,
          rejected: AuditWorkOrder.where(status: 'rejected').count
        },
        communication: {
          pending: CommunicationWorkOrder.where(status: 'pending').count,
          processing: CommunicationWorkOrder.where(status: 'processing').count,
          needs_communication: CommunicationWorkOrder.where(status: 'needs_communication').count,
          approved: CommunicationWorkOrder.where(status: 'approved').count,
          rejected: CommunicationWorkOrder.where(status: 'rejected').count
        }
      }

      render json: counts
    end

    def fee_detail_verification_counts
      counts = {
        pending: FeeDetail.where(verification_status: 'pending').count,
        problematic: FeeDetail.where(verification_status: 'problematic').count,
        verified: FeeDetail.where(verification_status: 'verified').count
      }

      render json: counts
    end
  end

  page_action :reimbursement_status_counts, method: :get
  page_action :work_order_status_counts, method: :get
  page_action :fee_detail_verification_counts, method: :get
end