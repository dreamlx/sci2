# WorkOrderProblemCommand - Command pattern for work order problem operations
class WorkOrderProblemCommand
  include ActiveModel::Model
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  # Simple result object for command responses
  class CommandResult
    attr_reader :success, :data, :errors

    def initialize(success:, data: nil, errors: [])
      @success = success
      @data = data
      @errors = errors
    end

    def success?
      @success
    end

    def message
      if success?
        'Work order problem successfully created'
      else
        'Work order problem creation failed'
      end
    end
  end

  attr_accessor :work_order_id, :problem_type_id, :description, :severity, :reported_by, :admin_user_id, :resolved, :suggested_action, :impact_assessment

  validates :work_order_id, presence: true
  validates :problem_type_id, presence: true

  attr_reader :work_order, :problem_type, :admin_user

  def initialize(attributes = {})
    @work_order_id = attributes[:work_order_id]
    @problem_type_id = attributes[:problem_type_id]
    @description = attributes[:description]
    @severity = attributes[:severity] || 'medium'
    @reported_by = attributes[:reported_by]
    @admin_user_id = attributes[:admin_user_id]
    @resolved = attributes[:resolved] || false
    @suggested_action = attributes[:suggested_action]
    @impact_assessment = attributes[:impact_assessment]
    @admin_user = AdminUser.find(admin_user_id) if admin_user_id.present?
  end

  def persisted?
    false
  end

  def call
    return CommandResult.new(success: false, errors: errors.full_messages) unless valid?

    begin
      @work_order = WorkOrder.find(work_order_id)
      @problem_type = ProblemType.find(problem_type_id)

      work_order_problem = create_work_order_problem

      CommandResult.new(success: true, data: work_order_problem)
    rescue ActiveRecord::RecordNotFound => e
      errors.add(:base, "Record not found: #{e.message}")
      CommandResult.new(success: false, errors: errors.full_messages)
    rescue ActiveRecord::RecordInvalid => e
      errors.add(:base, e.message)
      CommandResult.new(success: false, errors: errors.full_messages)
    end
  end

  private

  def create_work_order_problem
    work_order.work_order_problems.create!(
      problem_type: problem_type
    )
  end

  end