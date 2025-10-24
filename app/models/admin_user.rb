class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :work_order_operations, dependent: :nullify

  # 报销单分配关联
  has_many :assigned_reimbursements, class_name: 'ReimbursementAssignment', foreign_key: 'assignee_id'
  has_many :active_assigned_reimbursements, lambda {
    where(is_active: true)
  }, class_name: 'ReimbursementAssignment', foreign_key: 'assignee_id'
  has_many :reimbursements_to_process, through: :active_assigned_reimbursements, source: :reimbursement
  has_many :reimbursement_assignments_made, class_name: 'ReimbursementAssignment', foreign_key: 'assigner_id'

  # Enums for roles
  enum role: { admin: 'admin', super_admin: 'super_admin', regular: 'regular' }

  # Enums for status
  enum status: { active: 'active', inactive: 'inactive', suspended: 'suspended', deleted: 'deleted' }

  # Scopes
  scope :available, -> { where(status: %w[active inactive suspended]) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :active_users, -> { where(status: 'active') }
  scope :exclude_deleted, -> { where.not(status: 'deleted').or(where(deleted_at: nil)) }

  # Callbacks
  after_create :assign_super_admin_role, if: -> { !Rails.env.test? && AdminUser.count == 1 }
  before_create :set_default_role

  # Devise override - 只允许活跃用户登录
  def active_for_authentication?
    super && active?
  end

  # 获取用户状态的显示名称
  def status_display
    case status
    when 'active'
      '活跃'
    when 'inactive'
      '非活跃'
    when 'suspended'
      '暂停'
    when 'deleted'
      '已删除'
    else
      status
    end
  end

  # 软删除方法
  def soft_delete
    update(status: 'deleted', deleted_at: Time.current)
  end

  # 恢复用户
  def restore
    update(status: 'active', deleted_at: nil)
  end

  # 检查用户是否被软删除
  def deleted?
    deleted_at.present? || status == 'deleted'
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at email encrypted_password id id_value name telephone remember_created_at
       reset_password_sent_at reset_password_token updated_at role status deleted_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[active_assigned_reimbursements assigned_reimbursements reimbursement_assignments_made
       reimbursements_to_process work_order_operations]
  end

  # Find admin user by checking if the given string contains the admin user's name
  def self.find_by_name_substring(name_substring)
    return nil unless name_substring.present?

    all.find { |user| name_substring.include?(user.name) }
  end

  private

  def set_default_role
    self.role ||= :admin
  end

  def assign_super_admin_role
    update(role: 'super_admin')
  end
end
