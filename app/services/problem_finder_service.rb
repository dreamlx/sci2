# app/services/problem_finder_service.rb
class ProblemFinderService
  # This service implements the final, nuanced logic for finding applicable problem types.
  # It balances the need for precise matching with the reality of unstructured user input.
  # The strategy is "Best-Effort Precise Match + Guaranteed General Match".
  def self.find_for(reimbursement, fee_detail)
    # Step 1: Determine the reliable context.
    rt_code = determine_reimbursement_type(reimbursement)
    mt_code = fee_detail.flex_field_7

    return ProblemType.none if rt_code.blank? || mt_code.blank?

    # Step 2: Perform the "Best-Effort Precise Match".
    # We take the user-entered string from `fee_detail.fee_type` and try to find a matching
    # `FeeType` record within the same reimbursement and meeting context.
    matched_fee_type = FeeType.find_by(
      reimbursement_type_code: rt_code,
      meeting_type_code: mt_code,
      name: fee_detail.fee_type
    )
    
    precise_et_code = matched_fee_type&.expense_type_code

    # Step 3: Build the scopes.
    # Always include the "General" problems for this context.
    general_scope = ProblemType.where(
      reimbursement_type_code: rt_code,
      meeting_type_code: mt_code,
      expense_type_code: '00'
    )

    # If we found a precise match, include those problems as well.
    if precise_et_code.present?
      precise_scope = ProblemType.where(
        reimbursement_type_code: rt_code,
        meeting_type_code: mt_code,
        expense_type_code: precise_et_code
      )
      
      # Combine both scopes with a UNION.
      ProblemType.from(
        "(#{precise_scope.to_sql} UNION #{general_scope.to_sql}) AS problem_types"
      )
    else
      # If no precise match was found, just return the general problems.
      general_scope
    end
  end

  private

  def self.determine_reimbursement_type(reimbursement)
    case reimbursement.document_name
    when /^个人日常/
      'EN'
    when /^学术会议/
      'MN'
    else
      nil
    end
  end
end