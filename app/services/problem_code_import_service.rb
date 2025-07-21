# app/services/problem_code_import_service.rb
require 'csv'
require 'digest'

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
      error: nil,
      details: {
        fee_types: [],
        problem_types: []
      }
    }
    
    begin
      ActiveRecord::Base.transaction do
        puts "Starting import from #{@file_path}"
        # Read file content and remove BOM if present
        content = File.read(@file_path)
        content = content.sub("\xEF\xBB\xBF", '') if content.start_with?("\xEF\xBB\xBF")
        
        CSV.parse(content, headers: true, encoding: 'UTF-8') do |row|
          puts "Processing row: #{row.inspect}"
          fee_type_created, fee_type_updated, problem_type_created, problem_type_updated, fee_type_obj, problem_type_obj = process_row(row)
          
          result[:imported_fee_types] += 1 if fee_type_created
          result[:updated_fee_types] += 1 if fee_type_updated
          result[:imported_problem_types] += 1 if problem_type_created
          result[:updated_problem_types] += 1 if problem_type_updated
          
          # 记录详细信息
          if fee_type_created && fee_type_obj
            result[:details][:fee_types] << { code: fee_type_obj.code, title: fee_type_obj.title, action: "created" }
          elsif fee_type_updated && fee_type_obj
            result[:details][:fee_types] << { code: fee_type_obj.code, title: fee_type_obj.title, action: "updated" }
          end
          
          if problem_type_created && problem_type_obj
            result[:details][:problem_types] << {
              code: problem_type_obj.code,
              title: problem_type_obj.title,
              fee_type: fee_type_obj&.display_name || "未关联",
              action: "created"
            }
          elsif problem_type_updated && problem_type_obj
            result[:details][:problem_types] << {
              code: problem_type_obj.code,
              title: problem_type_obj.title,
              fee_type: fee_type_obj&.display_name || "未关联",
              action: "updated"
            }
          end
        end
      end
    rescue => e
      result[:success] = false
      result[:error] = "#{e.message}\n#{e.backtrace.join("\n")}"
      puts "Error during import: #{e.message}"
      puts e.backtrace
    end
    
    result
  end
  
  private
  
  def process_row(row)
    # Extract meeting type from Meeting Code
    meeting_code = row['Meeting Code']&.strip
    meeting_type = row['会议类型']&.strip
    
    # Extract fee type information
    exp_code = row['Expense Code']&.strip # Original Exp. Code from CSV
    fee_type_title = row['费用类型']&.strip # Use 费用类型 for the title field
    
    # Extract problem type information
    mn_code = row['Document Code']&.strip
    problem_code = row['Issue Code']&.strip
    problem_title = row['问题类型']&.strip
    sop_description = row['SOP描述']&.strip
    standard_handling = row['标准处理方法']&.strip
    
    # Skip if essential data is missing
    if exp_code.blank? || fee_type_title.blank? || problem_code.blank? || problem_title.blank? || meeting_code.blank? || meeting_type.blank?
      puts "Skipping row due to missing data: #{row.inspect}"
      return [false, false, false, false]
    end
    
    # Track if records were created or updated
    fee_type_created = false
    fee_type_updated = false
    problem_type_created = false
    problem_type_updated = false
    
    # 使用 Meeting Code + Expense Code 作为费用类型代码
    fee_type_code = "#{meeting_code}#{exp_code}"
    
    # 优先按code查找费用类型，确保正确的更新或创建逻辑
    fee_type = FeeType.find_by(code: fee_type_code)
    
    if fee_type
      # Update the code if it doesn't match the original exp_code
      if fee_type.code != fee_type_code
        fee_type.update(code: fee_type_code)
        fee_type_updated = true
      end
    else
      # Create a new fee type with the original exp_code
      fee_type = FeeType.create(
        code: fee_type_code,
        title: fee_type_title,
        meeting_type: meeting_type,
        active: true
      )
      fee_type_created = true
    end
    
    # Update fee type if it exists but has different attributes
    if !fee_type_created && (fee_type.title != fee_type_title || fee_type.meeting_type != meeting_type)
      fee_type.update(
        title: fee_type_title,
        meeting_type: meeting_type
      )
      fee_type_updated = true
    else
      fee_type_updated = false
    end
    
    # Find or create problem type using MN Code as the unique identifier
    # If fee_type_code is blank, create problem type without fee_type association
    if fee_type_code.blank?
      problem_type = ProblemType.find_or_create_by(code: mn_code) do |pt|
        pt.title = problem_title
        pt.sop_description = sop_description || "标准操作流程待定"
        pt.standard_handling = standard_handling || "标准处理方法待定"
        pt.active = true
        problem_type_created = true
      end
    else
      problem_type = ProblemType.find_or_initialize_by(code: mn_code)
      if problem_type.new_record?
        problem_type.assign_attributes(
          title: problem_title,
          sop_description: sop_description || "标准操作流程待定",
          standard_handling: standard_handling || "标准处理方法待定",
          active: true,
          fee_type_id: fee_type.id
        )
        problem_type.save!
        problem_type_created = true
      else
        # Update existing problem type
        problem_type.fee_type_id = fee_type.id if fee_type.present?
        problem_type.title = problem_title if problem_title.present?
        problem_type.sop_description = sop_description if sop_description.present?
        problem_type.standard_handling = standard_handling if standard_handling.present?
        if problem_type.changed?
          problem_type.save!
          problem_type_updated = true
        end
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
    
    [fee_type_created, fee_type_updated, problem_type_created, problem_type_updated, fee_type, problem_type]
  end
end