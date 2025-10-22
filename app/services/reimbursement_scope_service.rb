class ReimbursementScopeService
  attr_reader :current_user, :params

  def initialize(current_user, params = {})
    @current_user = current_user
    @params = params || {}
  end

  # Apply scope filtering to an association chain
  # @param end_of_association_chain [ActiveRecord::Relation] The base relation to filter
  # @return [ActiveRecord::Relation] The filtered relation
  def filtered_collection(end_of_association_chain)
    chain = end_of_association_chain

    # If viewing a single reimbursement (show action), don't apply any scope
    # This ensures that even unassigned reimbursements can be viewed by ID
    if params[:id].present?
      return chain
    end

    # Get the current selected scope
    current_scope = params[:scope]

    # Apply appropriate filter based on the scope
    case current_scope
    when 'assigned_to_me'
      # "分配给我的"scope - 显示分配给当前用户的报销单
      chain.assigned_to_user(current_user.id)
    when 'with_unread_updates'
      # "有新通知"scope - 只显示分配给当前用户且有未读更新的报销单
      chain.assigned_with_unread_updates(current_user.id)
    when 'pending', 'processing', 'closed'
      # 状态相关的scope - 只显示分配给当前用户且状态匹配的报销单
      chain.assigned_to_user(current_user.id).where(status: current_scope)
    when 'unassigned'
      # "未分配的"scope - 显示未分配的报销单，所有角色都可以看到
      chain.left_joins(:active_assignment).where(reimbursement_assignments: { id: nil }, status: 'pending')
    when 'all', nil, ''
      # "所有"scope或空参数 - 显示所有报销单
      chain
    else
      # 其他scope - 默认显示所有报销单
      chain
    end
  end

  # Alias for filtered_collection to maintain compatibility
  def scoped_collection(end_of_association_chain)
    filtered_collection(end_of_association_chain)
  end

  private
end