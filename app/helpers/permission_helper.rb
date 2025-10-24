# frozen_string_literal: true

# Helper module for displaying permission-related UI elements
# Provides consistent permission alerts and role indicators across ActiveAdmin
module PermissionHelper
  # Display role badge with appropriate styling
  def role_badge(user)
    return content_tag(:span, '未登录', class: 'role-badge unknown') unless user.present?

    role_class = case user.role
                 when 'super_admin'
                   'super-admin'
                 when 'admin'
                   'admin'
                 else
                   'unknown'
                 end

    role_name = case user.role
                when 'super_admin'
                  '超级管理员'
                when 'admin'
                  '管理员'
                else
                  '未知角色'
                end

    content_tag(:span, role_name, class: "role-badge #{role_class}")
  end

  # Display permission notice with warning style
  def permission_notice(message, type: :warning)
    css_class = case type
                when :warning
                  'permission-notice warning'
                when :info
                  'permission-notice info'
                when :error
                  'permission-notice error'
                else
                  'permission-notice'
                end

    content_tag(:div, class: css_class) do
      content_tag(:span, message, class: 'permission-text')
    end
  end

  # Display permission alert for actions that are not available
  def permission_alert(action:, resource_type: nil)
    message = case action
              when :assign, :batch_assign
                '您没有权限执行分配操作，请联系超级管理员'
              when :import
                "您没有权限导入#{resource_type}，请联系超级管理员"
              when :delete, :destroy
                "您没有权限删除#{resource_type}，请联系超级管理员"
              when :edit, :update
                "您没有权限编辑#{resource_type}，请联系超级管理员"
              else
                '您没有权限执行此操作，请联系超级管理员'
              end

    permission_notice(message, type: :warning)
  end

  # Display role information panel
  def role_info_panel(user, policy = nil)
    content_tag(:div, class: 'role-notice-panel') do
      content_tag(:div, class: 'role-info') do
        role_badge(user)
      end

      if policy && !policy.can_assign?
        content_tag(:div, class: 'permission-notice') do
          content_tag(:span, policy.authorization_error_message(action: :assign), class: 'warning-text')
        end
      end
    end
  end

  # Display disabled action button with tooltip
  def disabled_action_button(text, reason: nil, **options)
    default_options = {
      class: 'button disabled',
      disabled: true,
      title: reason || '您没有权限执行此操作'
    }

    button_tag(text, **default_options, **options)
  end

  # Display permission restricted indicator
  def permission_restricted_indicator
    content_tag(:span, '🔒', class: 'permission-restricted', title: '权限受限')
  end

  # Check if user can perform action and display appropriate UI
  def permission_guard(_user, policy, action)
    if policy.send("can_#{action}?")
      yield if block_given?
    else
      permission_alert(action: action)
    end
  end

  # Display permission info tooltip
  def permission_tooltip(text)
    content_tag(:span, class: 'permission-tooltip') do
      content_tag(:i, '', class: 'fas fa-info-circle') +
        content_tag(:span, text, class: 'tooltip-text')
    end
  end
end
