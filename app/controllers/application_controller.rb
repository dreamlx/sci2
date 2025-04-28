class ApplicationController < ActionController::Base
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
