# app/services/problem_code_import_service.rb
require 'csv'

class ProblemCodeImportService
  def initialize(file_path)
    @file_path = file_path
  end

  def import
    result = initialize_result
    
    begin
      content = File.read(@file_path)
      content.strip!
      content.sub!("\xEF\xBB\xBF", '')

      CSV.parse(content, headers: true, encoding: 'UTF-8').each do |row|
        process_row(row, result)
      end
    rescue => e
      result[:success] = false
      result[:error] = e.message
    end
    
    result
  end

  private

  def initialize_result
    { success: true, error: nil, details: { fee_types: [], problem_types: [] } }
  end

  def process_row(row, result)
    fee_type_params = {
      reimbursement_type_code: row['reimbursement_type_code'],
      meeting_type_code: row['meeting_type_code'],
      expense_type_code: row['expense_type_code'],
      name: row['expense_type_name'],
      meeting_name: row['meeting_type_name']
    }

    problem_type_params = {
      issue_code: row['issue_code'],
      title: row['problem_title'],
      sop_description: row['sop_description'],
      standard_handling: row['standard_handling'],
    }

    # Skip if essential data is missing
    return if fee_type_params.values_at(:reimbursement_type_code, :meeting_type_code, :expense_type_code).any?(&:blank?)
    return if problem_type_params.values.any?(&:blank?)

    # Process FeeType
    fee_type, fee_type_action = process_fee_type(fee_type_params)
    update_result_with_action(result, :fee_types, fee_type_action, fee_type.as_json)
    
    # Process ProblemType
    problem_type, problem_type_action = process_problem_type(problem_type_params, fee_type)
    update_result_with_action(result, :problem_types, problem_type_action, problem_type.as_json)
  end

  def process_fee_type(params)
    fee_type = FeeType.find_or_initialize_by(
      reimbursement_type_code: params[:reimbursement_type_code],
      meeting_type_code: params[:meeting_type_code],
      expense_type_code: params[:expense_type_code]
    )
    
    action = fee_type.new_record? ? :imported : :updated
    
    fee_type.assign_attributes(
      name: params[:name],
      meeting_name: params[:meeting_name],
      active: true
    )
    
    fee_type.save! if fee_type.changed?
    
    [fee_type, action]
  end
  
  def process_problem_type(params, fee_type)
    problem_type = ProblemType.find_or_initialize_by(
      fee_type_id: fee_type.id,
      issue_code: params[:issue_code]
    )

    action = problem_type.new_record? ? :imported : :updated
    
    problem_type.assign_attributes(
      title: params[:title],
      sop_description: params[:sop_description],
      standard_handling: params[:standard_handling],
      active: true
    )
    
    # 触发虚拟字段计算，确保 legacy_problem_code 数据库列被正确设置
    problem_type.legacy_problem_code
    
    problem_type.save! if problem_type.changed?
    
    [problem_type, action]
  end

  def update_result_with_action(result, type, action, details)
    return unless action
    details['action'] = action
    result[:details][type] << details
  end
end