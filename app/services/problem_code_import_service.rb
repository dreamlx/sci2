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

      # 移除外层事务，避免与测试事务冲突
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
    {
      success: true, error: nil,
      imported_fee_types: 0, updated_fee_types: 0,
      imported_problem_types: 0, updated_problem_types: 0,
      details: { fee_types: [], problem_types: [] }
    }
  end

  def process_row(row, result)
    # Standardize row data
    fee_type_params = {
      reimbursement_type_code: row['reimbursement_type_code']&.strip,
      meeting_type_code: row['meeting_type_code']&.strip,
      expense_type_code: row['expense_type_code']&.strip,
      name: row['expense_type_name']&.strip,
      meeting_name: row['meeting_type_name']&.strip
    }

    problem_type_params = {
      reimbursement_type_code: fee_type_params[:reimbursement_type_code],
      meeting_type_code: fee_type_params[:meeting_type_code],
      expense_type_code: fee_type_params[:expense_type_code],
      code: row['issue_code']&.strip,
      title: row['problem_title']&.strip,
      sop_description: row['sop_description']&.strip,
      standard_handling: row['standard_handling']&.strip
      # 移除 legacy_problem_code，因为它现在是虚拟字段
    }
    
    # Skip if essential data is missing
    return if fee_type_params.values.any?(&:blank?) || problem_type_params.values.any?(&:blank?)

    # Process FeeType
    fee_type, fee_type_action = process_fee_type(fee_type_params)
    update_result_with_action(result, :fee_types, fee_type_action, fee_type.as_json)
    
    # Process ProblemType
    problem_type_params[:name] = fee_type_params[:name]
    problem_type, problem_type_action = process_problem_type(problem_type_params)
    update_result_with_action(result, :problem_types, problem_type_action, problem_type.as_json)
  end

  def process_fee_type(params)
    # FeeType is now uniquely identified by the combination of its context codes.
    fee_type = FeeType.find_or_initialize_by(
      reimbursement_type_code: params[:reimbursement_type_code],
      meeting_type_code: params[:meeting_type_code],
      expense_type_code: params[:expense_type_code]
    )
    
    action = fee_type.new_record? ? :imported : :updated
    
    fee_type.name = params[:name]
    fee_type.meeting_name = params[:meeting_name]
    fee_type.save! if fee_type.changed?
    
    [fee_type, action]
  end
  
  def process_problem_type(params)
    problem_type = ProblemType.find_or_initialize_by(
      reimbursement_type_code: params[:reimbursement_type_code],
      meeting_type_code: params[:meeting_type_code],
      expense_type_code: params[:expense_type_code],
      code: params[:code]
    )

    action = problem_type.new_record? ? :imported : :updated
    
    problem_type.assign_attributes(
      title: params[:title],
      sop_description: params[:sop_description],
      standard_handling: params[:standard_handling],
      active: true
      # 移除 legacy_problem_code 赋值，因为它现在是虚拟字段
    )
    
    # 触发虚拟字段计算，确保 legacy_problem_code 数据库列被正确设置
    problem_type.legacy_problem_code
    
    if problem_type.changed?
      problem_type.save!
    else
      # 即使没有变更也要尝试保存，以检查验证错误
      problem_type.save!
    end
    
    [problem_type, action]
  end

  def update_result_with_action(result, type, action, details)
    return unless action
    result["#{action}_#{type}".to_sym] += 1
    result[:details][type] << details.merge(action: action)
  end
end