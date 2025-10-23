# frozen_string_literal: true

# Policy object for handling authorization logic related to AdminUser resources
# Centralizes permission checks and provides clear business rules for access control
class AdminUserPolicy
  attr_reader :user, :admin_user

  def initialize(user, admin_user = nil)
    @user = user
    @admin_user = admin_user
  end

  # Index permissions - Only super admins can view admin users
  def can_index?
    super_admin?
  end

  # Show permissions - Only super admins can view individual admin users
  def can_show?
    super_admin?
  end

  # View permissions (alias for can_show?)
  def can_view?
    can_show?
  end

  # Create permissions - Only super admins can create admin users
  def can_create?
    super_admin?
  end

  # Update permissions - Only super admins can update admin users
  def can_update?
    super_admin?
  end

  # Edit permissions (alias for can_update?)
  def can_edit?
    can_update?
  end

  # Destroy permissions - Only super admins can delete admin users
  def can_destroy?
    super_admin?
  end

  # Soft delete permissions - Only super admins can soft delete
  def can_soft_delete?
    super_admin?
  end

  # Restore permissions - Only super admins can restore deleted users
  def can_restore?
    super_admin?
  end

  # Batch operations permissions - Only super admins can perform batch operations
  def can_batch_soft_delete?
    super_admin?
  end

  def can_batch_restore?
    super_admin?
  end

  def can_batch_set_active?
    super_admin?
  end

  def can_batch_set_inactive?
    super_admin?
  end

  # Role management permissions - Only super admins can change roles
  def can_change_role?
    super_admin?
  end

  # Status management permissions - Only super admins can change status
  def can_change_status?
    super_admin?
  end

  # Self-management permissions - Users can update their own basic info
  def can_update_own_profile?
    return false unless user_present?
    return true if super_admin?

    # Regular admin users can only update their own profile (except role and status)
    user&.id == admin_user&.id
  end

  # Password change permissions - Users can change their own password
  def can_change_own_password?
    return false unless user_present?
    return true if super_admin?

    user&.id == admin_user&.id
  end

  # Action visibility for buttons/links
  def show_admin_users_menu?
    can_index?
  end

  def show_batch_actions?
    super_admin?
  end

  def show_soft_delete_button?
    can_soft_delete?
  end

  def show_restore_button?
    can_restore?
  end

  def show_role_field?
    super_admin?
  end

  def show_status_field?
    super_admin?
  end

  # Role-based display names
  def role_display_name
    case user&.role
    when 'super_admin'
      '超级管理员'
    when 'admin'
      '管理员'
    else
      '未知角色'
    end
  end

  # Permission error messages
  def authorization_error_message(action:)
    case action
    when :index, :show, :view
      '您没有权限查看管理员用户列表，请联系超级管理员'
    when :create, :update, :edit
      '您没有权限创建或修改管理员用户，请联系超级管理员'
    when :destroy, :soft_delete, :restore
      '您没有权限删除或恢复管理员用户，请联系超级管理员'
    when :batch_soft_delete, :batch_restore, :batch_set_active, :batch_set_inactive
      '您没有权限执行批量操作，请联系超级管理员'
    when :change_role, :change_status
      '您没有权限修改用户角色或状态，请联系超级管理员'
    when :update_own_profile
      '您只能修改自己的个人信息，请联系超级管理员修改其他用户信息'
    when :change_own_password
      '您只能修改自己的密码，请联系超级管理员修改其他用户密码'
    else
      '您没有权限执行此操作，请联系超级管理员'
    end
  end

  # Class methods for quick permission checks
  class << self
    def can_index?(user)
      new(user).can_index?
    end

    def can_show?(user, admin_user)
      new(user, admin_user).can_show?
    end

    def can_create?(user)
      new(user).can_create?
    end

    def can_update?(user, admin_user)
      new(user, admin_user).can_update?
    end

    def can_soft_delete?(user)
      new(user).can_soft_delete?
    end
  end

  private

  # Helper method to check if user exists
  def user_present?
    user.present?
  end

  # Helper method to check super admin status
  def super_admin?
    user&.super_admin? || false
  end

  # Helper method to check if this is the current user's own profile
  def own_profile?
    user_present? && admin_user.present? && user.id == admin_user.id
  end
end