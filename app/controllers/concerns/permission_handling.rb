# frozen_string_literal: true

# Concern for handling permission-related errors and redirects
# Provides consistent error handling across ActiveAdmin controllers
module PermissionHandling
  extend ActiveSupport::Concern

  included do
    rescue_from CanCan::AccessDenied do |exception|
      handle_permission_denied(exception)
    end
  end

  private

  # Handle permission denied errors with user-friendly messages
  def handle_permission_denied(exception)
    # Determine if this is an ActiveAdmin request
    if request.path.start_with?('/admin')
      handle_activeadmin_permission_denied(exception)
    else
      handle_api_permission_denied(exception)
    end
  end

  # Handle permission denied in ActiveAdmin context
  def handle_activeadmin_permission_denied(exception)
    # Try to determine the action from the request
    action = determine_action_from_request
    resource_type = determine_resource_type_from_request

    # Generate user-friendly message
    message = generate_permission_message(action, resource_type)

    # Store message in flash for display
    flash[:alert] = message
    flash[:permission_denied] = true

    # Redirect to appropriate location
    redirect_to_permission_denied_location
  end

  # Handle permission denied in API context
  def handle_api_permission_denied(exception)
    render json: {
      error: 'Permission Denied',
      message: exception.message,
      code: 'PERMISSION_DENIED'
    }, status: :forbidden
  end

  # Determine the action from the current request
  def determine_action_from_request
    case request.method_symbol
    when :get
      if request.path.include?('/new')
        :create
      elsif request.path.include?('/edit')
        :edit
      else
        :view
      end
    when :post
      :create
    when :put, :patch
      :update
    when :delete
      :destroy
    else
      :unknown
    end
  end

  # Determine resource type from request path
  def determine_resource_type_from_request
    path_parts = request.path.split('/')
    # Find the first part that looks like a resource name after /admin/
    admin_index = path_parts.index('admin')
    return '未知资源' unless admin_index

    resource_part = path_parts[admin_index + 1]
    return '未知资源' unless resource_part

    # Convert English resource names to Chinese
    case resource_part
    when 'reimbursements'
      '报销单'
    when 'admin_users'
      '管理员用户'
    when 'fee_details'
      '费用明细'
    when 'imports'
      '导入功能'
    when 'work_orders'
      '工单'
    else
      resource_part.humanize
    end
  end

  # Generate user-friendly permission message
  def generate_permission_message(action, resource_type)
    case action
    when :view
      "您没有权限查看#{resource_type}，请联系超级管理员获取相应权限。"
    when :create
      "您没有权限创建#{resource_type}，请联系超级管理员获取相应权限。"
    when :edit, :update
      "您没有权限编辑#{resource_type}，请联系超级管理员获取相应权限。"
    when :destroy
      "您没有权限删除#{resource_type}，请联系超级管理员获取相应权限。"
    when :assign
      "您没有权限分配#{resource_type}，请联系超级管理员获取相应权限。"
    when :import
      "您没有权限导入#{resource_type}，请联系超级管理员获取相应权限。"
    else
      "您没有权限执行此操作，请联系超级管理员获取相应权限。"
    end
  end

  # Determine where to redirect after permission denied
  def redirect_to_permission_denied_location
    # If user is not logged in, redirect to login
    unless current_admin_user
      return redirect_to new_admin_user_session_path
    end

    # Try to redirect to a safe location based on user role
    if current_admin_user.super_admin?
      # Super admins can go to dashboard
      redirect_to admin_dashboard_path
    else
      # Regular admins go to reimbursements (their main resource)
      redirect_to admin_reimbursements_path
    end
  end

  # Check if user has permission and show appropriate UI
  def verify_permission(policy_class, action, resource = nil)
    policy = policy_class.new(current_admin_user, resource)
    unless policy.send("can_#{action}?")
      message = policy.authorization_error_message(action: action)
      raise CanCan::AccessDenied.new(message, action, resource ? resource.class : nil)
    end
  end

  # Render permission denied notice in ActiveAdmin views
  def render_permission_denied_notice(action:, resource_type: nil, policy: nil)
    if policy
      message = policy.authorization_error_message(action: action)
    else
      message = generate_permission_message(action, resource_type)
    end

    render partial: 'admin/shared/permission_denied', locals: {
      message: message,
      action: action,
      resource_type: resource_type
    }
  end
end