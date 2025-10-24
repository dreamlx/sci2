# frozen_string_literal: true

# CurrentUserSupport - 测试环境中Current.admin_user的设置
module CurrentUserSupport
  extend ActiveSupport::Concern

  included do
    before { reset_current_user }
    after { reset_current_user }
  end

  class_methods do
    def set_current_user(user)
      Current.admin_user = user
    end

    def reset_current_user
      Current.admin_user = nil
    end
  end

  def set_current_user(user)
    Current.admin_user = user
  end

  def reset_current_user
    Current.admin_user = nil
  end
end