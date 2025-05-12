# app/controllers/admin/base_controller.rb
# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :authenticate_admin_user!
    layout 'active_admin'

    protected

    def current_admin_user
      current_user
    end
  end
end 