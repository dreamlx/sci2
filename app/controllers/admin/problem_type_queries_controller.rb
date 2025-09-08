class Admin::ProblemTypeQueriesController < ApplicationController
  before_action :authenticate_admin_user!
  
  def for_fee_details
    reimbursement = Reimbursement.find_by(id: params[:reimbursement_id])
    fee_detail_ids = params[:fee_detail_ids]&.split(',')

    if reimbursement.nil? || fee_detail_ids.blank?
      render json: { error: "Missing reimbursement_id or fee_detail_ids" }, status: :bad_request
      return
    end

    service = ProblemTypeQueryService.new(
      fee_detail_ids: fee_detail_ids,
      reimbursement: reimbursement
    )
    problem_types = service.call

    render json: problem_types.to_json(
      only: [:id, :issue_code, :title, :fee_type_id, :sop_description, :standard_handling],
      methods: [:display_name, :legacy_problem_code],
      include: {
        fee_type: {
          only: [:id, :name, :reimbursement_type_code, :meeting_type_code, :expense_type_code]
        }
      }
    )
  end
end