class WorkOrderProblem < ApplicationRecord
  # 关联
  belongs_to :work_order
  belongs_to :problem_type

  # 验证
  validates :work_order_id, uniqueness: { scope: :problem_type_id, message: '已关联此问题类型' }

  # Ransack 搜索权限
  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id id_value problem_type_id updated_at work_order_id]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[problem_type work_order]
  end

  # 回调
  after_create :log_problem_added
  after_destroy :log_problem_removed

  private

  # 记录问题添加操作
  def log_problem_added
    return unless defined?(WorkOrderOperation)

    WorkOrderOperation.create!(
      work_order: work_order,
      operation_type: WorkOrderOperation::OPERATION_TYPE_ADD_PROBLEM,
      details: "添加问题: #{problem_type.display_name}",
      admin_user_id: work_order&.creator&.id
    )
  end

  # 记录问题移除操作
  def log_problem_removed
    return unless defined?(WorkOrderOperation)

    WorkOrderOperation.create!(
      work_order: work_order,
      operation_type: WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM,
      details: "移除问题: #{problem_type.display_name}",
      admin_user_id: Current.admin_user&.id
    )
  end
end
