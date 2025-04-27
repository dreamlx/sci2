require_relative '../../lib/current'

class ApplicationController < ActionController::Base
  

  before_action :set_current_admin_user

  private

  def set_current_admin_user
    Current.admin_user = current_admin_user if defined?(current_admin_user) && current_admin_user.is_a?(AdminUser)
  end
end
