# app/services/work_order_service.rb
# frozen_string_literal: true

class WorkOrderService
  attr_reader :work_order, :current_admin_user

  def initialize(work_order, current_admin_user)
    raise ArgumentError, "Expected an instance of WorkOrder or its subclass" unless work_order.is_a?(WorkOrder)
    @work_order = work_order
    @current_admin_user = current_admin_user
    Current.admin_user = current_admin_user # Set Current context
    @operation_service = WorkOrderOperationService.new(work_order, current_admin_user)
  end

  # REMOVED: start_processing method as 'processing' state is removed.
  # If there was other logic here besides state change, it needs to be re-evaluated.

  def approve(params = {})
    # 添加调试日志
    Rails.logger.debug "WorkOrderService#approve: 开始处理工单 ##{@work_order.id}, 当前状态: #{@work_order.status}"
    Rails.logger.debug "WorkOrderService#approve: 参数: #{params.inspect}"
    
    # Assign attributes like audit_comment. The processing_opinion might be in params.
    # Model validations will check for audit_comment if opinion is '可以通过'
    assign_shared_attributes(params)
    
    Rails.logger.debug "WorkOrderService#approve: 分配属性后，处理意见: #{@work_order.processing_opinion}"
    Rails.logger.debug "WorkOrderService#approve: 分配属性后，工单状态: #{@work_order.status}"

    # 直接尝试调用 approve 方法，不再检查 can_approve?
    begin
      # 设置处理意见为"可以通过"
      @work_order.processing_opinion = '可以通过'
      Rails.logger.debug "WorkOrderService#approve: 设置处理意见为'可以通过'"
      
      # 调用 approve 方法更新状态
      Rails.logger.debug "WorkOrderService#approve: 调用 @work_order.approve 方法"
      result = @work_order.approve
      Rails.logger.debug "WorkOrderService#approve: @work_order.approve 返回结果: #{result}"
      Rails.logger.debug "WorkOrderService#approve: 调用 approve 后，工单状态: #{@work_order.status}"
      
      # 确保状态已更新
      if result && @work_order.status == "approved"
        Rails.logger.debug "WorkOrderService#approve: 状态已更新为 approved，开始同步费用明细状态"
        # 手动触发费用明细状态更新
        @work_order.send(:sync_fee_details_verification_status)
        
        # 记录状态变更操作
        @operation_service.record_status_change("pending", "approved")
        Rails.logger.debug "WorkOrderService#approve: 状态变更操作已记录"
        
        # Model's after_transition should set audit_date
        # Model's validations for approved state should have run.
        Rails.logger.debug "WorkOrderService#approve: 操作成功完成"
        return true unless @work_order.errors.any? # Check for validation errors after state change
      else
        Rails.logger.debug "WorkOrderService#approve: 状态更新失败，当前状态: #{@work_order.status}, 错误: #{@work_order.errors.full_messages.join(', ')}"
      end
    rescue StateMachines::InvalidTransition => e
      Rails.logger.debug "WorkOrderService#approve: 无法批准工单，当前状态: #{@work_order.status}, 错误: #{e.message}"
      @work_order.errors.add(:base, "无法批准工单 (当前状态: #{@work_order.status}): #{e.message}") unless @work_order.errors.any?
      Rails.logger.debug "WorkOrderService#approve: 返回 false，操作失败"
      false
    end
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
    # 添加调试日志
    Rails.logger.debug "WorkOrderService#reject: 开始处理工单 ##{@work_order.id}, 当前状态: #{@work_order.status}"
    Rails.logger.debug "WorkOrderService#reject: 参数: #{params.inspect}"
    
    # Assign attributes like audit_comment, problem_type_id etc.
    # Model validations will check for these if opinion is '无法通过'
    assign_shared_attributes(params)
    
    Rails.logger.debug "WorkOrderService#reject: 分配属性后，处理意见: #{@work_order.processing_opinion}"
    Rails.logger.debug "WorkOrderService#reject: 分配属性后，工单状态: #{@work_order.status}"

    # 直接尝试调用 reject 方法，不再检查 can_reject?
    begin
      # 设置处理意见为"无法通过"
      @work_order.processing_opinion = '无法通过'
      Rails.logger.debug "WorkOrderService#reject: 设置处理意见为'无法通过'"
      
      # 调用 reject 方法更新状态
      Rails.logger.debug "WorkOrderService#reject: 调用 @work_order.reject 方法"
      result = @work_order.reject
      Rails.logger.debug "WorkOrderService#reject: @work_order.reject 返回结果: #{result}"
      Rails.logger.debug "WorkOrderService#reject: 调用 reject 后，工单状态: #{@work_order.status}"
      
      # 确保状态已更新
      if result && @work_order.status == "rejected"
        Rails.logger.debug "WorkOrderService#reject: 状态已更新为 rejected，开始同步费用明细状态"
        # 手动触发费用明细状态更新
        @work_order.send(:sync_fee_details_verification_status)
        
        # 记录状态变更操作
        @operation_service.record_status_change("pending", "rejected")
        Rails.logger.debug "WorkOrderService#reject: 状态变更操作已记录"
        
        # Model's after_transition should set audit_date
        # Model's validations for rejected state should have run.
        Rails.logger.debug "WorkOrderService#reject: 操作成功完成"
        return true unless @work_order.errors.any? # Check for validation errors after state change
      else
        Rails.logger.debug "WorkOrderService#reject: 状态更新失败，当前状态: #{@work_order.status}, 错误: #{@work_order.errors.full_messages.join(', ')}"
      end
    rescue StateMachines::InvalidTransition => e
      Rails.logger.debug "WorkOrderService#reject: 无法拒绝工单，当前状态: #{@work_order.status}, 错误: #{e.message}"
      @work_order.errors.add(:base, "无法拒绝工单 (当前状态: #{@work_order.status}): #{e.message}") unless @work_order.errors.any?
      Rails.logger.debug "WorkOrderService#reject: 返回 false，操作失败"
      false
    end
  rescue StateMachines::InvalidTransition => e
    @work_order.errors.add(:base, "无法拒绝 (状态无效的转换): #{e.message}")
    Rails.logger.error "WorkOrderService Error: #{e.message} for work order #{@work_order.id}"
    false
  rescue => e 
    @work_order.errors.add(:base, "拒绝工单时发生错误: #{e.message}")
    Rails.logger.error "WorkOrderService Error: #{e.message} for work order #{@work_order.id}"
    false
  end

  # General update method - now handles status changes based on processing_opinion
  def update(params = {})
    # 添加调试日志
    Rails.logger.debug "WorkOrderService#update: 开始更新工单 ##{@work_order.id}, 当前状态: #{@work_order.status}"
    Rails.logger.debug "WorkOrderService#update: 参数: #{params.inspect}"
    
    # Ensure work_order is not completed before allowing updates
    unless @work_order.editable?
      Rails.logger.debug "WorkOrderService#update: 工单不可编辑，当前状态: #{@work_order.status}"
      @work_order.errors.add(:base, "工单已完成，无法修改。")
      return false
    end

    # 保存更新前的属性
    changed_attributes = {}
    
    # 保存原始处理意见
    original_processing_opinion = @work_order.processing_opinion
    Rails.logger.debug "WorkOrderService#update: 原始处理意见: #{original_processing_opinion.inspect}"
    
    # 分配属性
    assign_shared_attributes(params)
    Rails.logger.debug "WorkOrderService#update: 分配属性后，处理意见: #{@work_order.processing_opinion.inspect}"
    Rails.logger.debug "WorkOrderService#update: 分配属性后，工单状态: #{@work_order.status}"
    
    # 检查处理意见是否变更
    processing_opinion_changed = @work_order.processing_opinion != original_processing_opinion
    Rails.logger.debug "WorkOrderService#update: 处理意见是否变更: #{processing_opinion_changed}"
    
    # 检查哪些属性发生了变化
    @work_order.changed.each do |attr|
      changed_attributes[attr] = @work_order.send("#{attr}_was")
    end
    Rails.logger.debug "WorkOrderService#update: 变更的属性: #{changed_attributes.inspect}"
    
    # 如果处理意见变更为"可以通过"或"无法通过"，则调用相应的方法
    if processing_opinion_changed
      Rails.logger.debug "WorkOrderService#update: 处理意见已变更，新处理意见: #{@work_order.processing_opinion}"
      case @work_order.processing_opinion
      when '可以通过'
        Rails.logger.debug "WorkOrderService#update: 调用 approve 方法"
        return approve(params)
      when '无法通过'
        Rails.logger.debug "WorkOrderService#update: 调用 reject 方法"
        return reject(params)
      end
    end
    
    Rails.logger.debug "WorkOrderService#update: 调用 save_work_order 方法"
    if save_work_order("更新")
      # 记录更新操作
      @operation_service.record_update(changed_attributes) if changed_attributes.any?
      Rails.logger.debug "WorkOrderService#update: 更新成功"
      true
    else
      Rails.logger.debug "WorkOrderService#update: 更新失败，错误: #{@work_order.errors.full_messages.join(', ')}"
      false
    end
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
  
  # 处理费用明细选择
  def process_fee_detail_selections(fee_detail_ids)
    return if fee_detail_ids.blank?
    
    # 清除现有关联
    @work_order.work_order_fee_details.destroy_all
    
    # 创建新关联
    fee_detail_ids.each do |fee_detail_id|
      fee_detail = FeeDetail.find_by(id: fee_detail_id)
      next unless fee_detail
      
      # 确保费用明细属于同一个报销单
      next unless fee_detail.document_number == @work_order.reimbursement.invoice_number
      
      # 创建关联
      WorkOrderFeeDetail.create!(
        work_order: @work_order,
        fee_detail: fee_detail,
        work_order_type: @work_order.type
      )
    end
  end
  
  def assign_shared_attributes(params)
    Rails.logger.debug "WorkOrderService#assign_shared_attributes: 开始分配属性，参数: #{params.inspect}"
    
    shared_attr_keys = [
      :processing_opinion, :audit_comment,
      :problem_type_id, :fee_type_id,
      # AuditWorkOrder specific fields that are now shared due to alignment
      :audit_result # audit_result if it's set directly, though status implies it
                                   # For CommunicationWorkOrder, these would be nil or handled by model defaults if any
    ]
    
    Rails.logger.debug "WorkOrderService#assign_shared_attributes: 共享属性键: #{shared_attr_keys.inspect}"
    
    attrs_to_assign = params.slice(*shared_attr_keys.select { |key| params.key?(key) })
    Rails.logger.debug "WorkOrderService#assign_shared_attributes: 要分配的属性: #{attrs_to_assign.inspect}"
    
    # Ensure audit_result is not directly assigned if it's purely driven by status
    # If audit_result is a direct input field (e.g. from a form for specific cases), this is fine.
    # But our current design: status implies audit_result ('approved'/'rejected')
    attrs_to_assign.delete(:audit_result) # Let status dictate this, model has audit_result column for db persistence
    
    # Handle fee_type_id separately - it's not directly stored but used to filter problem_types
    fee_type_id = attrs_to_assign.delete(:fee_type_id)
    Rails.logger.debug "WorkOrderService#assign_shared_attributes: 费用类型ID: #{fee_type_id.inspect}"
    
    submitted_fee_detail_ids = attrs_to_assign.delete(:submitted_fee_detail_ids)
    Rails.logger.debug "WorkOrderService#assign_shared_attributes: 提交的费用明细IDs: #{submitted_fee_detail_ids.inspect}"
    
    # Assign the remaining attributes
    if attrs_to_assign.present?
      Rails.logger.debug "WorkOrderService#assign_shared_attributes: 分配剩余属性: #{attrs_to_assign.inspect}"
      @work_order.assign_attributes(attrs_to_assign)
    end
    
    # 处理费用明细选择
    if submitted_fee_detail_ids.present?
      Rails.logger.debug "WorkOrderService#assign_shared_attributes: 处理费用明细选择"
      process_fee_detail_selections(submitted_fee_detail_ids)
    end
    
    # 费用类型现在由选择的费用明细自动决定，不再需要单独处理 fee_type_id
    # 保留 fee_type_id 变量以兼容旧代码，但不再使用它来设置默认问题类型
    if fee_type_id.present?
      Rails.logger.debug "WorkOrderService#assign_shared_attributes: 设置费用类型ID: #{fee_type_id}"
      @work_order.fee_type_id = fee_type_id
    else
      Rails.logger.debug "WorkOrderService#assign_shared_attributes: 没有提供费用类型ID"
    end
    
    Rails.logger.debug "WorkOrderService#assign_shared_attributes: 分配属性完成，工单: #{@work_order.inspect}"
    
    # 移除自动填充审核意见的代码
    # 根据最新需求，审核意见完全由用户手动输入，不再自动填充
  end
end