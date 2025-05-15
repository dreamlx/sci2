# app/services/work_order_service.rb
# frozen_string_literal: true

class WorkOrderService
  attr_reader :work_order, :current_admin_user

  def initialize(work_order, current_admin_user)
    raise ArgumentError, "Expected an instance of WorkOrder or its subclass" unless work_order.is_a?(WorkOrder)
    @work_order = work_order
    @current_admin_user = current_admin_user
    Current.admin_user = current_admin_user # Set Current context
  end

  # REMOVED: start_processing method as 'processing' state is removed.
  # If there was other logic here besides state change, it needs to be re-evaluated.

  def approve(params = {})
    # Assign attributes like audit_comment. The processing_opinion might be in params.
    # Model validations will check for audit_comment if opinion is '可以通过'
    assign_shared_attributes(params) 

    if @work_order.may_mark_as_approved? 
      @work_order.mark_as_approved!(@current_admin_user)
      # Model's after_transition should set audit_date
      # Model's validations for approved state should have run.
      return true unless @work_order.errors.any? # Check for validation errors after state change
    else
      @work_order.errors.add(:base, "无法批准工单 (当前状态: #{@work_order.status})。") unless @work_order.errors.any?
    end
    false
  rescue StateMachines::InvalidTransition => e
    @work_order.errors.add(:base, "无法批准 (状态无效的转换): #{e.message}")
    Rails.logger.error "WorkOrderService Error: #{e.message} for work order #{@work_order.id}"
    false
  rescue => e 
    @work_order.errors.add(:base, "批准工单时发生错误: #{e.message}")
    Rails.logger.error "WorkOrderService Error: #{e.message} for work order #{@work_order.id}"
    false
  end

  def reject(params = {})
    # Assign attributes like audit_comment, problem_type_id etc.
    # Model validations will check for these if opinion is '无法通过'
    assign_shared_attributes(params) 

    if @work_order.may_mark_as_rejected? 
      @work_order.mark_as_rejected!(@current_admin_user)
      # Model's after_transition should set audit_date
      # Model's validations for rejected state should have run.
      return true unless @work_order.errors.any? # Check for validation errors after state change
    else
      @work_order.errors.add(:base, "无法拒绝工单 (当前状态: #{@work_order.status})。") unless @work_order.errors.any?
    end
    false
  rescue StateMachines::InvalidTransition => e
    @work_order.errors.add(:base, "无法拒绝 (状态无效的转换): #{e.message}")
    Rails.logger.error "WorkOrderService Error: #{e.message} for work order #{@work_order.id}"
    false
  rescue => e 
    @work_order.errors.add(:base, "拒绝工单时发生错误: #{e.message}")
    Rails.logger.error "WorkOrderService Error: #{e.message} for work order #{@work_order.id}"
    false
  end

  # General update method - should not change status via processing_opinion anymore.
  # Status changes are handled by approve/reject methods.
  def update(params = {})
    # Ensure work_order is not completed before allowing updates
    unless @work_order.editable?
      @work_order.errors.add(:base, "工单已完成，无法修改。")
      return false
    end

    assign_shared_attributes(params)
    # processing_opinion might be in params. If it changes, model validations related to it will run.
    # However, status change is not automatically triggered by opinion change here.
    
    save_work_order("更新")
  end

  # Method to mark a work order as truly completed (sets the boolean flag)
  def mark_as_truly_completed
    if @work_order.mark_as_truly_completed(@current_admin_user) # Call model method
      true
    else
      # Errors will be on @work_order.errors from the model method
      false
    end
  end

  # Update fee detail verification status (remains largely the same)
  def update_fee_detail_verification(fee_detail_id, verification_status, comment = nil)
    # Ensure work_order is not completed
    unless @work_order.editable?
      @work_order.errors.add(:base, "工单已完成，无法修改费用明细验证状态。")
      return false
    end

    fee_detail = @work_order.fee_details.find_by(id: fee_detail_id)

    unless fee_detail
      error_msg = "费用明细 ##{fee_detail_id} 未找到或未与此工单关联。"
      @work_order.errors.add(:base, error_msg)
      return false
    end

    # Assuming FeeDetailVerificationService is still relevant and handles its own logic
    verification_service = FeeDetailVerificationService.new(@current_admin_user)
    result = verification_service.update_verification_status(fee_detail, verification_status, comment)

    unless result
      fee_detail.errors.full_messages.each do |msg|
        @work_order.errors.add(:base, "费用明细 ##{fee_detail.id} 更新失败: #{msg}")
      end
    end
    result
  rescue => e
    @work_order.errors.add(:base, "更新费用明细 ##{fee_detail_id} 验证状态时发生内部错误: #{e.message}")
    false
  end

  private

  def save_work_order(action_name = "保存")
    begin
      if @work_order.save
        true
      else
        # Errors should already be on @work_order.errors from the save failure (including validation failures)
        Rails.logger.error "WorkOrderService: 无法#{action_name}工单 ##{@work_order.id}. 错误: #{@work_order.errors.full_messages.join(", ")}"
        false
      end
    rescue StateMachines::InvalidTransition => e
      # This exception occurs if a state transition fails due to validations within the state machine event.
      # The errors should already be on @work_order.errors by the validation process.
      Rails.logger.warn "WorkOrderService: State transition failed for ##{@work_order.id} during #{action_name}. Error: #{e.message}. Validation errors: #{@work_order.errors.full_messages.join(", ")}"
      # Ensure errors from the exception message are also on the object if not already captured by validations (though they should be)
      # Example: @work_order.errors.add(:base, e.message) unless @work_order.errors.full_messages.include?(e.message)
      false # Indicate failure
    end
  end
  
  def assign_shared_attributes(params)
    shared_attr_keys = [
      :remark, :processing_opinion, :audit_comment, 
      :problem_type_id, :problem_description_id,
      # AuditWorkOrder specific fields that are now shared due to alignment
      :audit_result # audit_result if it's set directly, though status implies it
                                   # For CommunicationWorkOrder, these would be nil or handled by model defaults if any
    ]
    
    attrs_to_assign = params.slice(*shared_attr_keys.select { |key| params.key?(key) })
    
    # Ensure audit_result is not directly assigned if it's purely driven by status
    # If audit_result is a direct input field (e.g. from a form for specific cases), this is fine.
    # But our current design: status implies audit_result ('approved'/'rejected')
    attrs_to_assign.delete(:audit_result) # Let status dictate this, model has audit_result column for db persistence

    @work_order.assign_attributes(attrs_to_assign) if attrs_to_assign.present?
  end
end 