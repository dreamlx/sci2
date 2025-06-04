# app/services/work_order_problem_service.rb
class WorkOrderProblemService
  def initialize(work_order)
    @work_order = work_order
  end
  
  # 添加多个问题类型
  def add_problems(problem_type_ids)
    return false if problem_type_ids.blank?
    
    # 转换为数组并确保是整数
    problem_type_ids = Array(problem_type_ids).map(&:to_i).uniq
    
    # 获取现有问题ID
    existing_ids = @work_order.work_order_problems.pluck(:problem_type_id)
    
    # 计算需要添加和删除的ID
    ids_to_add = problem_type_ids - existing_ids
    ids_to_remove = existing_ids - problem_type_ids
    
    # 添加新问题
    ids_to_add.each do |problem_type_id|
      @work_order.work_order_problems.create(problem_type_id: problem_type_id)
    end
    
    # 删除不再需要的问题
    if ids_to_remove.any?
      @work_order.work_order_problems.where(problem_type_id: ids_to_remove).destroy_all
    end
    
    true
  end
  
  # 添加单个问题类型
  def add_problem(problem_type_id)
    return false if problem_type_id.blank?
    
    # 创建关联
    @work_order.work_order_problems.create(problem_type_id: problem_type_id)
    
    true
  end
  
  # 移除问题类型
  def remove_problem(problem_type_id)
    return false if problem_type_id.blank?
    
    # 查找并删除关联
    problem = @work_order.work_order_problems.find_by(problem_type_id: problem_type_id)
    problem&.destroy
    
    true
  end
  
  # 清除所有问题
  def clear_problems
    @work_order.work_order_problems.destroy_all
    
    # 如果工单还有旧的单一问题类型关联，也清除它
    if @work_order.respond_to?(:problem_type_id) && @work_order.problem_type_id.present?
      @work_order.update(problem_type_id: nil)
    end
    
    # 清除审核意见
    if @work_order.respond_to?(:audit_comment) && @work_order.audit_comment.present?
      @work_order.update(audit_comment: nil)
    end
    
    true
  end
  
  # 获取当前关联的所有问题类型
  def get_problems
    @work_order.problem_types
  end
  
  # 获取问题类型的格式化文本
  def get_formatted_problems
    @work_order.problem_types.map do |problem_type|
      format_problem(problem_type)
    end
  end
  
  # 生成审核意见文本（兼容旧版本）
  def generate_audit_comment
    problems = get_formatted_problems
    
    if problems.empty?
      nil
    else
      problems.join("\n\n")
    end
  end
  
  private
  
  # 格式化单个问题类型
  def format_problem(problem_type)
    fee_type_info = problem_type.fee_type.present? ? "#{problem_type.fee_type.display_name}: " : ""
    [
      "#{fee_type_info}#{problem_type.display_name}",
      "    #{problem_type.sop_description}",
      "    #{problem_type.standard_handling}"
    ].join("\n")
  end
end