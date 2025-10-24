class ApplicationController < ActionController::Base
  # 权限拒绝处理方法
  def access_denied(_exception)
    redirect_to admin_dashboard_path, alert: '您没有执行此操作的权限。'
  end

  # 设置默认本地化为中文
  before_action :set_locale

  protected

  def set_locale
    I18n.locale = :'zh-CN'
  end

  def redirect_to_admin
    redirect_to admin_root_path
  end

  # 添加 Devise 的 current_user 方法支持
  # 这个方法被 ActiveAdmin 和 CanCan 使用
  def current_user
    current_admin_user
  end

  # 定义 current_admin_user 方法
  def current_admin_user
    @current_admin_user ||= warden.authenticate(scope: :admin_user)
  end

  # 添加 authenticate_admin_user! 方法
  def authenticate_admin_user!
    redirect_to new_admin_user_session_path unless current_admin_user
  end
end
