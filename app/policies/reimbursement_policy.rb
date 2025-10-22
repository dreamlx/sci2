# frozen_string_literal: true

# Policy object for handling authorization logic related to Reimbursement resources
# Centralizes permission checks and provides clear business rules for access control
class ReimbursementPolicy
  attr_reader :user, :reimbursement

  def initialize(user, reimbursement = nil)
    @user = user
    @reimbursement = reimbursement
  end

  # Index permissions
  def can_index?
    # All authenticated users can view the reimbursement list
    user.present?
  end

  # Show permissions
  def can_show?
    # All authenticated users can view individual reimbursements
    user.present?
  end

  # View permissions (alias for can_show?)
  def can_view?
    can_show?
  end

  # Create permissions
  def can_create?
    # Only super admins can create new reimbursements
    user&.super_admin? || false
  end

  # Update permissions
  def can_update?
    # Only super admins can update reimbursements
    user&.super_admin? || false
  end

  # Edit permissions (alias for can_update?)
  def can_edit?
    can_update?
  end

  # Destroy permissions
  def can_destroy?
    # Only super admins can delete reimbursements
    user&.super_admin? || false
  end

  # Assignment permissions
  def can_assign?
    # Only super admins can assign reimbursements
    user&.super_admin? || false
  end

  def can_batch_assign?
    # Only super admins can batch assign reimbursements
    user&.super_admin? || false
  end

  def can_transfer_assignment?
    # Only super admins can transfer assignments
    user&.super_admin? || false
  end

  def can_unassign?
    # Only super admins can unassign reimbursements
    user&.super_admin? || false
  end

  # Manual override permissions
  def can_manual_override?
    # Only super admins can manually override status
    user&.super_admin? || false
  end

  def can_set_pending?
    # Only super admins can set status to pending
    user&.super_admin? || false
  end

  def can_set_processing?
    # Only super admins can set status to processing
    user&.super_admin? || false
  end

  def can_set_closed?
    # Only super admins can set status to closed
    user&.super_admin? || false
  end

  def can_reset_override?
    # Only super admins can reset manual overrides
    user&.super_admin? || false
  end

  # Attachment permissions
  def can_upload_attachment?
    # Only super admins can upload attachments
    user&.super_admin? || false
  end

  # Import permissions
  def can_import?
    # Only super admins can import reimbursements
    user&.super_admin? || false
  end

  # Export permissions
  def can_export?
    # All authenticated users can export
    user.present?
  end

  # Scope permissions for filtering
  def can_view_assigned_to_me?
    # Users can view reimbursements assigned to them
    user.present?
  end

  def can_view_all?
    # Only super admins can view all reimbursements without filtering
    user&.super_admin? || false
  end

  def can_view_unassigned?
    # Only super admins can view unassigned reimbursements
    user&.super_admin? || false
  end

  # Status-based permissions
  def can_view_pending?
    user.present?
  end

  def can_view_processing?
    user.present?
  end

  def can_view_closed?
    user.present?
  end

  def can_view_with_unread_updates?
    # Users can view reimbursements with unread updates assigned to them
    user.present?
  end

  # Action visibility for buttons/links
  def show_import_button?
    can_import?
  end

  def show_manual_override_section?
    can_manual_override?
  end

  def show_assignment_controls?
    can_assign?
  end

  def show_action_buttons?
    # Determine which action buttons to show based on user role
    return 'primary_action' if user&.super_admin?
    'disabled_action'
  end

  def show_batch_actions?
    # Only super admins can see batch actions
    user&.super_admin? || false
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
    when :assign, :batch_assign, :transfer_assignment, :unassign
      '您没有权限执行分配操作，请联系超级管理员'
    when :manual_override, :set_pending, :set_processing, :set_closed, :reset_override
      '您没有权限执行手动状态覆盖操作，请联系超级管理员'
    when :create, :update, :destroy
      '您没有权限执行此操作，请联系超级管理员'
    when :upload_attachment
      '您没有权限上传附件，请联系超级管理员'
    else
      '您没有权限执行此操作，请联系超级管理员'
    end
  end

  # Class methods for quick permission checks
  class << self
    def can_index?(user)
      new(user).can_index?
    end

    def can_show?(user, reimbursement)
      new(user, reimbursement).can_show?
    end

    def can_assign?(user)
      new(user).can_assign?
    end

    def can_manual_override?(user)
      new(user).can_manual_override?
    end

    def can_import?(user)
      new(user).can_import?
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