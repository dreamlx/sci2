class WorkOrderProblem < ApplicationRecord
  # 关联
  belongs_to :work_order
  belongs_to :problem_type

  # 验证
  validates :work_order_id, uniqueness: { scope: :problem_type_id, message: "已关联此问题类型" }

  # 回调
  after_create :log_problem_added
  after_destroy :log_problem_removed

  private

  # 记录问题添加操作
  def log_problem_added
    WorkOrderOperation.create!(
      work_order: work_order,
      operation_type: WorkOrderOperation::OPERATION_TYPE_ADD_PROBLEM,
      details: "添加问题: #{problem_type.display_name}",
      admin_user_id: Current.admin_user&.id
    ) if defined?(WorkOrderOperation)
  end

  # 记录问题移除操作
  def log_problem_removed
    WorkOrderOperation.create!(
      work_order: work_order,
      operation_type: WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM,
      details: "移除问题: #{problem_type.display_name}",
      admin_user_id: Current.admin_user&.id
    ) if defined?(WorkOrderOperation)
  end
end