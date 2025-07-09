# 报销单权限控制服务
# 负责管理基于角色的权限控制逻辑
class ReimbursementAuthorizationService
  def initialize(current_user)
    @current_user = current_user
  end

  # 检查是否可以执行分配操作
  def can_assign?
    @current_user.super_admin?
  end

  # 检查是否可以查看报销单
  def can_view?(reimbursement = nil)
    true # 所有管理员都可以查看所有报销单
  end

  # 检查是否可以编辑报销单
  def can_edit?(reimbursement = nil)
    true # 所有管理员都可以编辑所有报销单
  end

  # 检查是否可以删除报销单
  def can_delete?(reimbursement = nil)
    true # 所有管理员都可以删除所有报销单
  end

  # 获取默认scope
  def default_scope
    'all' # 所有用户默认都显示全部数据
  end

  # 应用基于角色的默认过滤（仅在无scope参数时使用）
  def apply_role_based_default_filter(collection)
    # 所有用户都可以看到所有数据，不再基于角色进行默认过滤
    collection
  end

  # 检查是否应该显示分配相关UI
  def should_show_assignment_ui?
    true # 总是显示，但根据权限决定是否禁用
  end

  # 获取分配按钮的CSS类（用于禁用样式）
  def assignment_button_class
    can_assign? ? 'primary_action' : 'disabled_action'
  end

  # 获取权限提示信息
  def assignment_permission_message
    can_assign? ? nil : '您没有权限执行分配操作，请联系超级管理员'
  end

  # 检查是否应该设置默认scope
  def should_use_default_scope?(params)
    # 当没有明确的scope参数时，应用默认过滤
    params[:scope].blank?
  end

  # 获取scope过滤后的集合
  def apply_scope_filter(collection, scope_param, params = {})
    case scope_param
    when 'pending', 'processing', 'closed'
      # 状态scope：所有用户都可以看到对应状态的所有报销单
      collection.where(status: scope_param)
    when 'assigned_to_me'
      # 明确指定分配给我的：只显示分配给当前用户的报销单
      collection.assigned_to_user(@current_user.id)
    when 'unassigned'
      # 未分配的：所有用户都可以看到所有未分配的报销单
      collection.left_joins(:active_assignment).where(reimbursement_assignments: { id: nil })
    when 'all'
      # 显示所有：所有用户都可以看到所有报销单
      collection
    when 'global_all'
      # 保留兼容性：全局所有数据scope
      collection
    else
      # 无scope参数或未知scope：应用默认角色过滤
      apply_role_based_default_filter(collection)
    end
  end

  # 检查是否应该使用全局视图（保留兼容性，但现在所有用户都有全局视图）
  def should_use_global_view?(params)
    true # 所有用户都有全局视图权限
  end
  
  # 检查普通管理员是否可以使用全局视图
  def can_use_global_view?
    true # 所有用户都可以使用全局视图
  end
  
  # 获取全局视图的提示信息
  def global_view_notice
    nil # 不再需要全局视图提示，因为这是默认行为
  end

  # 检查当前用户是否为普通管理员
  def admin?
    @current_user.admin?
  end

  # 检查当前用户是否为超级管理员
  def super_admin?
    @current_user.super_admin?
  end

  # 获取用户角色的显示名称
  def role_display_name
    case @current_user.role
    when 'admin'
      '普通管理员'
    when 'super_admin'
      '超级管理员'
    else
      '未知角色'
    end
  end

  # 检查是否应该显示默认scope提示
  def should_show_default_scope_notice?
    false # 不再需要显示默认scope提示，因为所有用户都能看到所有数据
  end

  # 获取默认scope的提示信息
  def default_scope_notice
    nil # 不再需要默认scope提示
  end

  private

  attr_reader :current_user
end