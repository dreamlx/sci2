class ReimbursementAssignment < ApplicationRecord
  belongs_to :reimbursement
  belongs_to :assignee, class_name: 'AdminUser'
  belongs_to :assigner, class_name: 'AdminUser'

  validates :reimbursement_id, uniqueness: { scope: :is_active, message: '已经有一个活跃的分配' }, if: :is_active?

  scope :active, -> { where(is_active: true) }
  scope :by_assignee, ->(assignee_id) { where(assignee_id: assignee_id) }
  scope :by_assigner, ->(assigner_id) { where(assigner_id: assigner_id) }
  scope :recent_first, -> { order(created_at: :desc) }

  after_create :deactivate_previous_assignments

  private

  def deactivate_previous_assignments
    return unless is_active?

    # 在 after_create 回调中，当前记录已经创建，所以需要排除它
    ReimbursementAssignment.where(reimbursement_id: reimbursement_id, is_active: true)
                           .where.not(id: id)
                           .update_all(is_active: false)
  end

  # Define ransackable attributes for ActiveAdmin search
  def self.ransackable_attributes(_auth_object = nil)
    %w[assignee_id assigner_id created_at id id_value is_active notes reimbursement_id
       updated_at]
  end

  # Define ransackable associations for ActiveAdmin search
  def self.ransackable_associations(_auth_object = nil)
    %w[assignee assigner reimbursement]
  end
end
