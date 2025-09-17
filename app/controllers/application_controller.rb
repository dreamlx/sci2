class ApplicationController < ActionController::Base
  # 权限拒绝处理方法
  def access_denied(exception)
    redirect_to admin_dashboard_path, alert: "您没有执行此操作的权限。"
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
end
