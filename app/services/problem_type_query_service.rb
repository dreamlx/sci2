# app/services/problem_type_query_service.rb
class ProblemTypeQueryService
  def initialize(fee_detail_ids:, reimbursement:)
    @fee_detail_ids = fee_detail_ids
    @reimbursement = reimbursement
    @selected_fee_details = FeeDetail.where(id: @fee_detail_ids)
  end

  def call
    return [] if @selected_fee_details.empty?
    
    specific_problems = find_specific_problems
    general_problems = find_general_problems
    
    result = (specific_problems + general_problems).uniq
    Rails.logger.debug "Final result: #{result.count} problem types found"
    Rails.logger.debug "Specific problems: #{specific_problems.count}, General problems: #{general_problems.count}"
    
    result
  end

  private

  def find_specific_problems
    problems = []
    reimbursement_type = determine_reimbursement_type
    
    @selected_fee_details.each do |fee_detail|
      Rails.logger.debug "FeeDetail: fee_type='#{fee_detail.fee_type}', flex_field_7='#{fee_detail.flex_field_7}'"
      
      meeting_code = MeetingCodeMappingService.call(fee_detail.flex_field_7)
      Rails.logger.debug "Mapped meeting_code: #{meeting_code}"

      next if meeting_code.blank?
      
      # Find the FeeType by its name and the context codes
      fee_type = FeeType.find_by(
        reimbursement_type_code: reimbursement_type,
        meeting_type_code: meeting_code,
        name: fee_detail.fee_type
      )
      
      Rails.logger.debug "Found FeeType: #{fee_type.inspect}"
      problems.concat(fee_type.problem_types) if fee_type
    end
    
    problems
  end

  def find_general_problems
    reimbursement_type = determine_reimbursement_type
    
    # Collect all unique meeting_type_codes from the selected fee details
    meeting_type_descriptions = @selected_fee_details.map(&:flex_field_7).uniq
    meeting_type_codes = meeting_type_descriptions.map { |desc| MeetingCodeMappingService.call(desc) }.compact.uniq
    Rails.logger.debug "Mapped meeting type codes: #{meeting_type_codes.inspect}"
    
    return [] if meeting_type_codes.empty?
    
    # Find all general fee types that match the context
    general_fee_types = FeeType.where(
      reimbursement_type_code: reimbursement_type,
      meeting_type_code: meeting_type_codes,
      expense_type_code: '00'
    )
    
    Rails.logger.debug "Found #{general_fee_types.count} general fee types"
    general_fee_types.each { |ft| Rails.logger.debug "General FeeType: #{ft.inspect}" }
    
    # Eager load problem types to avoid N+1 queries
    result = ProblemType.where(fee_type_id: general_fee_types.select(:id))
    Rails.logger.debug "Found #{result.count} general problem types"
    
    result
  end

  def determine_reimbursement_type
    # This logic is based on the user's description.
    # Adjust the document names as needed.
    Rails.logger.debug "Reimbursement document_name: '#{@reimbursement.document_name}'"
    
    result = case @reimbursement.document_name
    when "个人日常报销单", "差旅报销单"
      "EN"
    when "学术会议报销单"
      "MN"
    else
      # Default or error handling - let's be more flexible
      if @reimbursement.document_name&.include?("个人") || @reimbursement.document_name&.include?("差旅")
        "EN"
      elsif @reimbursement.document_name&.include?("学术") || @reimbursement.document_name&.include?("会议")
        "MN"
      else
        # Fallback to EN as default
        "EN"
      end
    end
    
    Rails.logger.debug "Determined reimbursement_type: '#{result}'"
    result
  end
end
