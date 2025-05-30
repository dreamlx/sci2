# app/services/problem_code_migration_service.rb
class ProblemCodeMigrationService
  def self.migrate_to_new_structure
    ActiveRecord::Base.transaction do
      migrate_fee_types
      migrate_problem_types
    end
  end
  
  private
  
  def self.migrate_fee_types
    # Create default meeting types if they don't exist
    personal_type = FeeType.find_or_create_by(code: "00", title: "个人费用", meeting_type: "个人")
    academic_type = FeeType.find_or_create_by(code: "01", title: "学术费用", meeting_type: "学术论坛")
    
    # Migrate existing fee types if any
    FeeType.where(code: nil).find_each.with_index do |fee_type, index|
      # Determine meeting type based on name or other logic
      meeting_type = determine_meeting_type(fee_type.name)
      
      # Generate a unique code
      code = generate_unique_code(fee_type, index)
      
      # Update the fee type
      fee_type.update(
        code: code,
        title: fee_type.name, # Use existing name as title
        meeting_type: meeting_type,
        active: true
      )
    end
  end
  
  def self.migrate_problem_types
    ProblemType.where(code: nil).find_each.with_index do |problem_type, index|
      # Determine fee_type based on problem_type name or other logic
      fee_type = determine_fee_type(problem_type)
      
      # Generate a unique code within the fee_type
      code = generate_unique_problem_code(problem_type, fee_type, index)
      
      # Get or create default SOP and handling if not available
      sop_description = get_sop_description(problem_type)
      standard_handling = get_standard_handling(problem_type)
      
      # Update the problem type
      problem_type.update(
        code: code,
        title: problem_type.name, # Use existing name as title
        sop_description: sop_description,
        standard_handling: standard_handling,
        fee_type_id: fee_type.id,
        active: problem_type.active
      )
    end
  end
  
  def self.determine_meeting_type(name)
    # Logic to determine meeting type based on name
    # This is a simple example - you would need more sophisticated logic based on your data
    return "个人" if name.to_s.include?("个人") || name.to_s.include?("交通") || name.to_s.include?("电话")
    return "学术论坛" if name.to_s.include?("学术") || name.to_s.include?("会议") || name.to_s.include?("论坛")
    "其他" # Default
  end
  
  def self.determine_fee_type(problem_type)
    # Logic to determine fee_type based on problem_type name or other attributes
    # Since document_category is no longer available, we'll use the problem_type name
    name = problem_type.name.to_s
    
    if name.include?("个人") || name.include?("交通") || name.include?("电话")
      return FeeType.find_by(meeting_type: "个人") || FeeType.first
    elsif name.include?("学术") || name.include?("会议") || name.include?("论坛")
      return FeeType.find_by(meeting_type: "学术论坛") || FeeType.first
    end
    
    # Default to first fee type if no match
    FeeType.first
  end
  
  def self.generate_unique_code(fee_type, index)
    # Generate a unique code for fee_type
    base_code = (index + 10).to_s # Start from "10" to avoid conflicts
    
    # Ensure code is unique
    while FeeType.exists?(code: base_code)
      base_code = (base_code.to_i + 1).to_s
    end
    
    base_code
  end
  
  def self.generate_unique_problem_code(problem_type, fee_type, index)
    # Generate a unique code for problem_type within fee_type
    base_code = (index + 10).to_s # Start from "10" to avoid conflicts
    
    # Ensure code is unique within fee_type
    while ProblemType.exists?(code: base_code, fee_type_id: fee_type.id)
      base_code = (base_code.to_i + 1).to_s
    end
    
    base_code
  end
  
  def self.get_sop_description(problem_type)
    # Try to get SOP description from problem_descriptions if available
    description = problem_type.problem_descriptions.first&.description if problem_type.respond_to?(:problem_descriptions)
    description.presence || "标准操作流程待定" # Default if not available
  end
  
  def self.get_standard_handling(problem_type)
    # This is a placeholder - you would need to implement based on your data
    "标准处理方法待定" # Default
  end
end