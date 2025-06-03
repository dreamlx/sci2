class ReimbursementQueryService
  def initialize(current_admin_user)
    @current_admin_user = current_admin_user
  end
  
  # 获取分配给当前用户的报销单
  # @param params [Hash] 查询参数
  # @return [ActiveRecord::Relation] 报销单查询结果
  def assigned_to_me(params = {})
    query = Reimbursement.joins(:active_assignment)
                        .where(reimbursement_assignments: { assignee_id: @current_admin_user.id })
    
    apply_filters(query, params)
  end
  
  # 获取所有报销单
  # @param params [Hash] 查询参数
  # @return [ActiveRecord::Relation] 报销单查询结果
  def all_reimbursements(params = {})
    query = Reimbursement.all
    
    apply_filters(query, params)
  end
  
  # 获取未分配的报销单
  # @param params [Hash] 查询参数
  # @return [ActiveRecord::Relation] 报销单查询结果
  def unassigned(params = {})
    query = Reimbursement.left_joins(:active_assignment)
                        .where(reimbursement_assignments: { id: nil })
    
    apply_filters(query, params)
  end
  
  # 获取分配给特定用户的报销单
  # @param assignee_id [Integer] 被分配人ID
  # @param params [Hash] 查询参数
  # @return [ActiveRecord::Relation] 报销单查询结果
  def assigned_to_user(assignee_id, params = {})
    query = Reimbursement.joins(:active_assignment)
                        .where(reimbursement_assignments: { assignee_id: assignee_id })
    
    apply_filters(query, params)
  end
  
  # 获取工作量统计
  # @return [Hash] 工作量统计结果
  def workload_statistics
    stats = {}
    
    # 获取所有管理员用户
    admin_users = AdminUser.all
    
    admin_users.each do |admin_user|
      # 分配的报销单数量
      assigned_count = ReimbursementAssignment.active.where(assignee_id: admin_user.id).count
      
      # 已处理的报销单数量
      processed_count = Reimbursement.joins(:active_assignment)
                                   .where(reimbursement_assignments: { assignee_id: admin_user.id })
                                   .where(status: Reimbursement::STATUS_CLOSED)
                                   .count
      
      # 待处理的报销单数量
      pending_count = Reimbursement.joins(:active_assignment)
                                 .where(reimbursement_assignments: { assignee_id: admin_user.id })
                                 .where.not(status: Reimbursement::STATUS_CLOSED)
                                 .count
      
      stats[admin_user.id] = {
        admin_user: admin_user,
        assigned_count: assigned_count,
        processed_count: processed_count,
        pending_count: pending_count,
        completion_rate: assigned_count > 0 ? (processed_count.to_f / assigned_count * 100).round(2) : 0
      }
    end
    
    stats
  end
  
  private
  
  # 应用过滤条件
  # @param query [ActiveRecord::Relation] 初始查询
  # @param params [Hash] 查询参数
  # @return [ActiveRecord::Relation] 应用过滤条件后的查询
  def apply_filters(query, params)
    # 状态过滤
    if params[:status].present?
      query = query.where(status: params[:status])
    end
    
    # 发票号过滤
    if params[:invoice_number].present?
      query = query.where('invoice_number LIKE ?', "%#{params[:invoice_number]}%")
    end
    
    # 申请人过滤
    if params[:applicant].present?
      query = query.where('applicant LIKE ?', "%#{params[:applicant]}%")
    end
    
    # 日期范围过滤
    if params[:start_date].present? && params[:end_date].present?
      query = query.where(created_at: params[:start_date]..params[:end_date])
    end
    
    # 金额范围过滤
    if params[:min_amount].present? && params[:max_amount].present?
      query = query.where(amount: params[:min_amount]..params[:max_amount])
    elsif params[:min_amount].present?
      query = query.where('amount >= ?', params[:min_amount])
    elsif params[:max_amount].present?
      query = query.where('amount <= ?', params[:max_amount])
    end
    
    # 排序
    if params[:sort_by].present?
      direction = params[:sort_direction] == 'desc' ? 'desc' : 'asc'
      query = query.order("#{params[:sort_by]} #{direction}")
    else
      query = query.order(created_at: :desc)
    end
    
    query
  end
end