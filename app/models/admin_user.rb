class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, 
         :recoverable, :rememberable, :validatable
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, 
         :recoverable, :rememberable, :validatable
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, 
         :recoverable, :rememberable, :validatable
  # Associations
  has_many :work_order_operations, dependent: :nullify
  
  # 报销单分配关联
  has_many :assigned_reimbursements, class_name: 'ReimbursementAssignment', foreign_key: 'assignee_id'
  has_many :active_assigned_reimbursements, -> { where(is_active: true) }, class_name: 'ReimbursementAssignment', foreign_key: 'assignee_id'
  has_many :reimbursements_to_process, through: :active_assigned_reimbursements, source: :reimbursement
  has_many :reimbursement_assignments_made, class_name: 'ReimbursementAssignment', foreign_key: 'assigner_id'
  
  # Enums for roles
  enum role: { admin: 'admin', super_admin: 'super_admin' }

  # Callbacks
  after_create :assign_super_admin_role, if: -> { AdminUser.count == 1 }
  before_create :set_default_role

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "email", "encrypted_password", "id", "id_value", "remember_created_at", "reset_password_sent_at", "reset_password_token", "updated_at", "role"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["active_assigned_reimbursements", "assigned_reimbursements", "reimbursement_assignments_made", "reimbursements_to_process", "work_order_operations"]
  end

  private

  def set_default_role
    self.role ||= :admin
  end

  def assign_super_admin_role
    update(role: 'super_admin')
  end

end
