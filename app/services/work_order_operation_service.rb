# app/services/work_order_operation_service.rb
class WorkOrderOperationService
  def initialize(work_order, admin_user)
    @work_order = work_order
    @admin_user = admin_user
  end

  # 记录工单创建操作
  def record_create
    record_operation(
      WorkOrderOperation::OPERATION_TYPE_CREATE,
      { message: '工单已创建' },
      nil,
      work_order_state
    )
  end

  # 记录工单更新操作
  def record_update(changed_attributes)
    return if changed_attributes.empty?

    previous = {}
    current = {}

    changed_attributes.each do |attr, old_value|
      previous[attr] = old_value
      current[attr] = @work_order.send(attr)
    end

    record_operation(
      WorkOrderOperation::OPERATION_TYPE_UPDATE,
      { changed_attributes: changed_attributes.keys },
      previous,
      current
    )
  end

  # 记录工单状态变更操作
  def record_status_change(from_status, to_status)
    record_operation(
      WorkOrderOperation::OPERATION_TYPE_STATUS_CHANGE,
      { from_status: from_status, to_status: to_status },
      { status: from_status },
      { status: to_status }
    )
  end

  # 记录添加问题操作
  def record_add_problem(problem_type_id, _problem_text)
    problem_type = ProblemType.find_by(id: problem_type_id)

    record_operation(
      WorkOrderOperation::OPERATION_TYPE_ADD_PROBLEM,
      {
        problem_type_id: problem_type_id,
        problem_type_code: problem_type&.legacy_problem_code,
        problem_type_title: problem_type&.title
      },
      { audit_comment: @work_order.audit_comment_was },
      { audit_comment: @work_order.audit_comment }
    )
  end

  # 记录移除问题操作
  def record_remove_problem(problem_type_id, old_content)
    problem_type = ProblemType.find_by(id: problem_type_id)

    record_operation(
      WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM,
      {
        problem_type_id: problem_type_id,
        problem_type_code: problem_type&.legacy_problem_code,
        problem_type_title: problem_type&.title
      },
      { audit_comment: old_content },
      { audit_comment: @work_order.audit_comment }
    )
  end

  # 记录修改问题操作
  def record_modify_problem(problem_type_id, old_text, new_text)
    problem_type = ProblemType.find_by(id: problem_type_id)

    record_operation(
      WorkOrderOperation::OPERATION_TYPE_MODIFY_PROBLEM,
      {
        problem_type_id: problem_type_id,
        problem_type_code: problem_type&.legacy_problem_code,
        problem_type_title: problem_type&.title
      },
      { audit_comment: old_text },
      { audit_comment: new_text }
    )
  end

  private

  # 记录操作的通用方法
  def record_operation(operation_type, details, previous_state, current_state)
    WorkOrderOperation.create!(
      work_order: @work_order,
      admin_user: @admin_user,
      operation_type: operation_type,
      details: details.to_json,
      previous_state: previous_state.to_json,
      current_state: current_state.to_json,
      created_at: Time.current
    )
  end

  # 获取工单当前状态的哈希表示
  def work_order_state
    {
      id: @work_order.id,
      type: @work_order.type,
      status: @work_order.status,
      reimbursement_id: @work_order.reimbursement_id,
      audit_comment: @work_order.audit_comment,
      problem_type_id: @work_order.problem_type_id,
      created_by: @work_order.created_by
    }
  end
end
