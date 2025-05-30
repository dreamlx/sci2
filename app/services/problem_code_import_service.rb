# app/services/problem_code_import_service.rb
require 'csv'

class ProblemCodeImportService
  def initialize(file_path)
    @file_path = file_path
  end
  
  def import
    result = {
      success: true,
      imported_fee_types: 0,
      imported_problem_types: 0,
      updated_fee_types: 0,
      updated_problem_types: 0,
      error: nil
    }
    
    begin
      ActiveRecord::Base.transaction do
        CSV.foreach(@file_path, headers: true, encoding: 'UTF-8') do |row|
          fee_type_created, fee_type_updated, problem_type_created, problem_type_updated = process_row(row)
          
          result[:imported_fee_types] += 1 if fee_type_created
          result[:updated_fee_types] += 1 if fee_type_updated
          result[:imported_problem_types] += 1 if problem_type_created
          result[:updated_problem_types] += 1 if problem_type_updated
        end
      end
    rescue => e
      result[:success] = false
      result[:error] = e.message
    end
    
    result
  end
  
  private
  
  def process_row(row)
    # Extract fee type information
    fee_type_code = row['Exp. Code']&.strip
    fee_type_title = row['费用类型']&.strip
    
    # Extract problem type information
    problem_code = row['Issue Code']&.strip
    problem_title = row['问题类型']&.strip
    sop_description = row['SOP描述']&.strip
    standard_handling = row['标准处理方法']&.strip
    
    # Skip if essential data is missing
    return [false, false, false, false] if fee_type_code.blank? || fee_type_title.blank? || problem_code.blank? || problem_title.blank?
    
    # Track if records were created or updated
    fee_type_created = false
    fee_type_updated = false
    problem_type_created = false
    problem_type_updated = false
    
    # Find or create fee type
    fee_type = FeeType.find_or_create_by(code: fee_type_code) do |ft|
      ft.title = fee_type_title
      ft.meeting_type = '个人' # 默认为个人类型
      ft.active = true
      fee_type_created = true
    end
    
    # Update fee type if it exists but has different title
    if !fee_type_created && fee_type.title != fee_type_title
      fee_type.update(title: fee_type_title)
      fee_type_updated = true
    end
    
    # Find or create problem type
    # If fee_type_code is blank, create problem type without fee_type association
    if fee_type_code.blank?
      problem_type = ProblemType.find_or_create_by(code: problem_code) do |pt|
        pt.title = problem_title
        pt.sop_description = sop_description || "标准操作流程待定"
        pt.standard_handling = standard_handling || "标准处理方法待定"
        pt.active = true
        problem_type_created = true
      end
    else
      problem_type = ProblemType.find_or_create_by(code: problem_code, fee_type_id: fee_type.id) do |pt|
        pt.title = problem_title
        pt.sop_description = sop_description || "标准操作流程待定"
        pt.standard_handling = standard_handling || "标准处理方法待定"
        pt.active = true
        problem_type_created = true
      end
    end
    
    # Update problem type if it exists but has different attributes
    if !problem_type_created
      should_update = false
      
      # Check if any attributes need updating
      should_update = true if problem_type.title != problem_title
      should_update = true if problem_type.sop_description != sop_description && sop_description.present?
      should_update = true if problem_type.standard_handling != standard_handling && standard_handling.present?
      
      # If fee_type_code is present but problem_type.fee_type_id is nil, update the fee_type_id
      if fee_type_code.present? && problem_type.fee_type_id.nil?
        should_update = true
        problem_type.fee_type_id = fee_type.id
      end
      
      # If any attributes need updating, update the problem_type
      if should_update
        problem_type.update(
          title: problem_title,
          sop_description: sop_description || problem_type.sop_description,
          standard_handling: standard_handling || problem_type.standard_handling
        )
        problem_type_updated = true
      end
    end
    
    [fee_type_created, fee_type_updated, problem_type_created, problem_type_updated]
  end
end