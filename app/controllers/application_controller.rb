class ApplicationController < ActionController::Base
  include ServiceRegistry

  before_action :set_current_admin_user

  private

  def set_current_admin_user
    Current.admin_user = current_admin_user if defined?(current_admin_user)
  end
end
