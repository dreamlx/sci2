# app/services/work_order_problem_service.rb
class WorkOrderProblemService
  def initialize(work_order)
    @work_order = work_order
  end
  
  # Add a problem to the work order's audit comment
  def add_problem(problem_type_id)
    problem_type = ProblemType.find(problem_type_id)
    
    # Format the problem information
    new_problem_text = format_problem(problem_type)
    
    # Update the work order's audit comment
    current_comment = @work_order.audit_comment.to_s.strip
    
    if current_comment.present?
      # Add a blank line between problems
      @work_order.audit_comment = "#{current_comment}\n\n#{new_problem_text}"
    else
      @work_order.audit_comment = new_problem_text
    end
    
    # Update the problem_type_id field (for reference)
    @work_order.problem_type_id = problem_type_id
    
    # Save the work order
    @work_order.save
  end
  
  # Clear all problems from the work order
  def clear_problems
    @work_order.update(audit_comment: nil, problem_type_id: nil)
  end
  
  # Get all problems from the work order's audit comment
  def get_problems
    return [] if @work_order.audit_comment.blank?
    
    # Split the audit comment by double newlines to get individual problems
    @work_order.audit_comment.split("\n\n").map(&:strip).reject(&:blank?)
  end
  
  private
  
  def format_problem(problem_type)
    fee_type = problem_type.fee_type
    
    # Format: "费用类型(code+title): 问题类型(code+title)"
    #         "    SOP描述内容"
    #         "    标准处理方法内容"
    [
      "#{fee_type.display_name}: #{problem_type.display_name}",
      "    #{problem_type.sop_description}",
      "    #{problem_type.standard_handling}"
    ].join("\n")
  end
end