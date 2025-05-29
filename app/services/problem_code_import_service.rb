# app/services/problem_code_import_service.rb
require 'csv'

class ProblemCodeImportService
  def initialize(file_path, meeting_type)
    @file_path = file_path
    @meeting_type = meeting_type
  end
  
  def import
    ActiveRecord::Base.transaction do
      CSV.foreach(@file_path, headers: true, encoding: 'UTF-8') do |row|
        process_row(row)
      end
    end
  end
  
  private
  
  def process_row(row)
    # Extract fee type information
    fee_type_code = row['费用类型代码']&.strip
    fee_type_title = row['费用类型名称']&.strip
    
    # Extract problem type information
    problem_code = row['问题代码']&.strip
    problem_title = row['问题名称']&.strip
    sop_description = row['SOP描述']&.strip
    standard_handling = row['标准处理方法']&.strip
    
    # Skip if essential data is missing
    return if fee_type_code.blank? || fee_type_title.blank? || problem_code.blank? || problem_title.blank?
    
    # Find or create fee type
    fee_type = FeeType.find_or_create_by(code: fee_type_code) do |ft|
      ft.title = fee_type_title
      ft.meeting_type = @meeting_type
      ft.active = true
    end
    
    # Update fee type if it exists but has different title
    if fee_type.title != fee_type_title
      fee_type.update(title: fee_type_title)
    end
    
    # Find or create problem type
    problem_type = ProblemType.find_or_create_by(code: problem_code, fee_type_id: fee_type.id) do |pt|
      pt.title = problem_title
      pt.sop_description = sop_description || "标准操作流程待定"
      pt.standard_handling = standard_handling || "标准处理方法待定"
      pt.active = true
    end
    
    # Update problem type if it exists but has different attributes
    if problem_type.title != problem_title || 
       problem_type.sop_description != sop_description ||
       problem_type.standard_handling != standard_handling
      
      problem_type.update(
        title: problem_title,
        sop_description: sop_description || problem_type.sop_description,
        standard_handling: standard_handling || problem_type.standard_handling
      )
    end
  end
end