class ReimbursementAssignmentService
  def initialize(current_admin_user)
    @current_admin_user = current_admin_user
  end
  
  # 分配单个报销单
  # @param reimbursement_id [Integer] 报销单ID
  # @param assignee_id [Integer] 被分配人ID
  # @param notes [String] 分配备注
  # @return [ReimbursementAssignment] 创建的分配记录
  def assign(reimbursement_id, assignee_id, notes = nil)
    reimbursement = Reimbursement.find(reimbursement_id)
    assignee = AdminUser.available.find(assignee_id)  # 只选择可用的用户（非删除状态）
    
    # 先取消该报销单的其他活跃分配
    ReimbursementAssignment.where(reimbursement_id: reimbursement_id, is_active: true)
                          .update_all(is_active: false)
    
    assignment = ReimbursementAssignment.new(
      reimbursement: reimbursement,
      assignee: assignee,
      assigner: @current_admin_user,
      is_active: true,
      notes: notes
    )
    
    if assignment.save
      # 记录操作
      record_assignment_operation(reimbursement, assignee)
      assignment
    else
      nil
    end
  end
  
  # 批量分配报销单
  # @param reimbursement_ids [Array<Integer>] 报销单ID数组
  # @param assignee_id [Integer] 被分配人ID
  # @param notes [String] 分配备注
  # @return [Array<ReimbursementAssignment>] 创建的分配记录数组
  def batch_assign(reimbursement_ids, assignee_id, notes = nil)
    assignee = AdminUser.available.find(assignee_id)  # 只选择可用的用户（非删除状态）
    assignments = []
    
    Reimbursement.where(id: reimbursement_ids).find_each do |reimbursement|
      # 先取消该报销单的其他活跃分配
      ReimbursementAssignment.where(reimbursement_id: reimbursement.id, is_active: true)
                            .update_all(is_active: false)
      
      assignment = ReimbursementAssignment.new(
        reimbursement: reimbursement,
        assignee: assignee,
        assigner: @current_admin_user,
        is_active: true,
        notes: notes
      )
      
      if assignment.save
        # 记录操作
        record_assignment_operation(reimbursement, assignee)
        assignments << assignment
      end
    end
    
    assignments
  end
  
  # 取消分配
  # @param assignment_id [Integer] 分配记录ID
  # @return [Boolean] 是否成功取消分配
  def unassign(assignment_id)
    assignment = ReimbursementAssignment.find(assignment_id)
    
    if assignment.update(is_active: false)
      # 记录操作
      record_unassignment_operation(assignment.reimbursement, assignment.assignee)
      true
    else
      false
    end
  end
  
  # 转移分配
  # @param reimbursement_id [Integer] 报销单ID
  # @param new_assignee_id [Integer] 新被分配人ID
  # @param notes [String] 分配备注
  # @return [ReimbursementAssignment] 创建的分配记录
  def transfer(reimbursement_id, new_assignee_id, notes = nil)
    reimbursement = Reimbursement.find(reimbursement_id)
    new_assignee = AdminUser.available.find(new_assignee_id)  # 只选择可用的用户（非删除状态）
    
    # 获取当前分配
    current_assignment = reimbursement.active_assignment
    
    # 如果没有当前分配，直接创建新分配
    if current_assignment.nil?
      return assign(reimbursement_id, new_assignee_id, notes)
    end
    
    # 取消当前分配
    current_assignment.update(is_active: false)
    
    # 创建新分配
    assignment = ReimbursementAssignment.new(
      reimbursement: reimbursement,
      assignee: new_assignee,
      assigner: @current_admin_user,
      is_active: true,
      notes: notes
    )
    
    if assignment.save
      # 记录操作
      record_transfer_operation(reimbursement, current_assignment.assignee, new_assignee)
      assignment
    else
      # 如果创建新分配失败，恢复当前分配
      current_assignment.update(is_active: true)
      nil
    end
  end
  
  private
  
  # 记录分配操作
  def record_assignment_operation(reimbursement, assignee)
    # 暂时不记录操作，等待工单操作记录服务完善后再实现
    # 这里可以添加日志记录
    Rails.logger.info("报销单 #{reimbursement.invoice_number} 分配给 #{assignee.email}")
  end
  
  # 记录取消分配操作
  def record_unassignment_operation(reimbursement, assignee)
    # 暂时不记录操作，等待工单操作记录服务完善后再实现
    # 这里可以添加日志记录
    Rails.logger.info("报销单 #{reimbursement.invoice_number} 取消分配 #{assignee.email}")
  end
  
  # 记录转移分配操作
  def record_transfer_operation(reimbursement, old_assignee, new_assignee)
    # 暂时不记录操作，等待工单操作记录服务完善后再实现
    # 这里可以添加日志记录
    Rails.logger.info("报销单 #{reimbursement.invoice_number} 从 #{old_assignee&.email} 转移给 #{new_assignee.email}")
  end
end
