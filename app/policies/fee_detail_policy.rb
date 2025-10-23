# frozen_string_literal: true

# Policy object for handling authorization logic related to FeeDetail resources
# Centralizes permission checks and provides clear business rules for access control
class FeeDetailPolicy
  attr_reader :user, :fee_detail

  def initialize(user, fee_detail = nil)
    @user = user
    @fee_detail = fee_detail
  end

  # Index permissions - All authenticated users can view fee details
  def can_index?
    user.present?
  end

  # Show permissions - All authenticated users can view individual fee details
  def can_show?
    user.present?
  end

  # View permissions (alias for can_show?)
  def can_view?
    can_show?
  end

  # Create permissions - Only super admins can create fee details
  def can_create?
    super_admin?
  end

  # Update permissions - Only super admins can update fee details
  def can_update?
    super_admin?
  end

  # Edit permissions (alias for can_update?)
  def can_edit?
    can_update?
  end

  # Destroy permissions - Only super admins can delete fee details
  def can_destroy?
    super_admin?
  end

  # Attachment upload permissions - Only super admins can upload attachments
  def can_upload_attachment?
    super_admin?
  end

  # Batch operations permissions - Only super admins can perform batch operations
  def can_batch_operations?
    super_admin?
  end

  # Action visibility for buttons/links
  def show_fee_details_menu?
    can_index?
  end

  def show_create_button?
    can_create?
  end

  def show_edit_button?
    can_edit?
  end

  def show_delete_button?
    can_destroy?
  end

  def show_attachment_upload?
    can_upload_attachment?
  end

  def show_batch_actions?
    can_batch_operations?
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
    when :create, :update, :edit
      '您没有权限创建或修改费用明细，请联系超级管理员'
    when :destroy
      '您没有权限删除费用明细，请联系超级管理员'
    when :upload_attachment
      '您没有权限上传附件，请联系超级管理员'
    when :batch_operations
      '您没有权限执行批量操作，请联系超级管理员'
    else
      '您没有权限执行此操作，请联系超级管理员'
    end
  end

  # Class methods for quick permission checks
  class << self
    def can_index?(user)
      new(user).can_index?
    end

    def can_show?(user, fee_detail)
      new(user, fee_detail).can_show?
    end

    def can_create?(user)
      new(user).can_create?
    end

    def can_update?(user, fee_detail)
      new(user, fee_detail).can_update?
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
end