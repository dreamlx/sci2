# WorkOrderProblemCommand - Command pattern for work order problem operations
class WorkOrderProblemCommand
  include ActiveModel::Model
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :work_order_id, :problem_type_id, :description, :severity, :reported_by, :admin_user_id, :resolved

  validates :work_order_id, presence: true
  validates :problem_type_id, presence: true
  validates :description, presence: true
  validates :severity, inclusion: { in: %w[low medium high critical] }
  validates :reported_by, presence: true

  attr_reader :work_order, :problem_type, :admin_user

  def initialize(attributes = {})
    @work_order_id = attributes[:work_order_id]
    @problem_type_id = attributes[:problem_type_id]
    @description = attributes[:description]
    @severity = attributes[:severity] || 'medium'
    @reported_by = attributes[:reported_by]
    @admin_user_id = attributes[:admin_user_id]
    @resolved = attributes[:resolved] || false
    @admin_user = AdminUser.find(admin_user_id) if admin_user_id.present?
  end

  def persisted?
    false
  end

  def call
    return false unless valid?

    @work_order = WorkOrder.find(work_order_id)
    @problem_type = ProblemType.find(problem_type_id)

    ActiveRecord::Base.transaction do
      create_work_order_problem
      update_work_order_status
      notify_admin_users
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  private

  def create_work_order_problem
    work_order.work_order_problems.create!(
      problem_type: problem_type,
      description: description,
      severity: severity,
      reported_by: reported_by,
      resolved: resolved,
      admin_user: admin_user
    )
  end

  def update_work_order_status
    work_order.update!(status: 'problem_reported') if work_order.may_transition_to?('problem_reported')
  end

  def notify_admin_users
    # Notification logic would go here
    Rails.logger.info "Work order problem reported: #{work_order.id} - #{description}"
  end
end