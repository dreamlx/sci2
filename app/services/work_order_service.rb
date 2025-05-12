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

  # Start processing
  def start_processing(params = {})
    assign_shared_attributes(params)
    @work_order.start_processing! # Uses the state machine event from WorkOrder model
    true
  rescue StateMachines::InvalidTransition => e
    @work_order.errors.add(:base, "无法开始处理 (状态无效的转换): #{e.message}")
    Rails.logger.error "WorkOrderService Error: #{e.message} for work order #{@work_order.id}"
    false
  rescue => e
    @work_order.errors.add(:base, "无法开始处理: #{e.message}")
    Rails.logger.error "WorkOrderService Error: #{e.message} for work order #{@work_order.id}"
    false
  end

  # Approve work order (sets resolution to approved, status change handled by model callback)
  def approve(params = {})
    assign_shared_attributes(params)

    # Common comment field for approval/rejection is audit_comment
    comment = params[:audit_comment]
    if comment.blank? && (@work_order.is_a?(AuditWorkOrder) || @work_order.is_a?(CommunicationWorkOrder))
      # For Audit and Communication work orders, a comment is typically required for approval/rejection.
      @work_order.errors.add(:audit_comment, "不能为空，请填写处理意见。")
      return false
    end
    @work_order.audit_comment = comment if comment.present? # Assign if provided
    
    @work_order.resolution = "approved"
    @work_order.approve! if @work_order.can_approve?
    
    save_work_order("批准")
  rescue StateMachines::InvalidTransition => e
    @work_order.errors.add(:base, "无法批准 (状态无效的转换): #{e.message}")
    false
  rescue => e
    @work_order.errors.add(:base, "无法批准: #{e.message}")
    false
  end

  # Reject work order (sets resolution to rejected, status change handled by model callback)
  def reject(params = {})
    assign_shared_attributes(params)
    comment = params[:audit_comment]

    if comment.blank? && (@work_order.is_a?(AuditWorkOrder) || @work_order.is_a?(CommunicationWorkOrder))
      @work_order.errors.add(:audit_comment, "不能为空，请填写处理意见。")
      return false
    end 
    @work_order.audit_comment = comment if comment.present?

    # Ensure required fields for rejection are present (e.g., problem_type, problem_description)
    # This check is more robust in the model's validation, but early check here is good.
    if @work_order.is_a?(AuditWorkOrder) || @work_order.is_a?(CommunicationWorkOrder)
      if params[:problem_type_id].blank? && @work_order.problem_type_id.blank?
        @work_order.errors.add(:problem_type_id, "不能为空")
      end
      if params[:problem_description_id].blank? && @work_order.problem_description_id.blank?
        @work_order.errors.add(:problem_description_id, "不能为空")
      end
      return false if @work_order.errors.any?
    end

    @work_order.resolution = "rejected"
    @work_order.reject! if @work_order.can_reject?

    save_work_order("拒绝")
  rescue StateMachines::InvalidTransition => e
    @work_order.errors.add(:base, "无法拒绝 (状态无效的转换): #{e.message}")
    false
  rescue => e
    @work_order.errors.add(:base, "无法拒绝: #{e.message}")
    false
  end

  # General update method, primarily driven by processing_opinion
  def update(params = {})
    assign_shared_attributes(params)
    
    # Determine resolution based on processing_opinion
    # The actual `processing_opinion` value is now on `@work_order.processing_opinion`
    # due to `assign_shared_attributes` if it was in `params`.

    new_resolution = @work_order.resolution # Keep current if no change from opinion
    should_reset_resolution = false

    if params.key?(:processing_opinion) # Check if processing_opinion was explicitly passed
      case @work_order.processing_opinion # This is the value from params or existing
      when "可以通过", "审核通过" # Added "审核通过" for AuditWorkOrder compatibility
        new_resolution = "approved"
        @work_order.status = "approved" if @work_order.pending? || @work_order.processing?
        @work_order.audit_date = Time.current if @work_order.respond_to?(:audit_date=)
      when "无法通过", "否决" # Added "否决" for AuditWorkOrder compatibility
        new_resolution = "rejected"
        @work_order.status = "rejected" if @work_order.pending? || @work_order.processing?
        @work_order.audit_date = Time.current if @work_order.respond_to?(:audit_date=)
        # Service-level checks for fields required when rejecting
        if (@work_order.is_a?(AuditWorkOrder) || @work_order.is_a?(CommunicationWorkOrder))
          # Check against current attributes which include params applied by assign_shared_attributes
          if @work_order.problem_type_id.blank?
            @work_order.errors.add(:problem_type_id, "不能为空，当处理意见为无法通过时。")
          end
          if @work_order.problem_description_id.blank?
            @work_order.errors.add(:problem_description_id, "不能为空，当处理意见为无法通过时。")
          end
          return false if @work_order.errors.any?
        end
      when nil, ""
        # If processing_opinion is explicitly cleared, resolution should go back to pending
        # and status (via callback) to processing if it was approved/rejected.
        if @work_order.resolution.in?(%w[approved rejected])
            new_resolution = "pending"
            should_reset_resolution = true
        end
      else
        # If processing_opinion is something else (e.g., a custom intermediate step not leading to final resolution)
        # We might just save attributes and not change resolution, or set status to processing.
        # For now, let's assume non-final opinions don't change final resolution unless explicitly handled.
        # If status is pending, and there's an opinion, it might imply starting processing.
        if @work_order.pending? && @work_order.processing_opinion.present?
          @work_order.status = "processing"
        end
      end
    end

    @work_order.resolution = new_resolution
    
    if @work_order.resolution_changed? || should_reset_resolution
      if new_resolution == "approved"
        @work_order.approve! if @work_order.can_approve?
      elsif new_resolution == "rejected"
        @work_order.reject! if @work_order.can_reject?
      elsif new_resolution == "pending"
        @work_order.reset_resolution! if @work_order.can_reset_resolution?
      end
    end

    # `audit_comment` and `audit_date` are handled by `assign_shared_attributes` (for comment)
    # and model callbacks (for date based on resolution/status change).
    save_work_order("更新")
  end

  # Update fee detail verification status
  def update_fee_detail_verification(fee_detail_id, verification_status, comment = nil)
    fee_detail = @work_order.fee_details.find_by(id: fee_detail_id)

    unless fee_detail
      error_msg = "费用明细 ##{fee_detail_id} 未找到或未与此工单关联。"
      @work_order.errors.add(:base, error_msg)
      return false
    end

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
    if @work_order.save
      true
    else
      # Errors are already on @work_order.errors
      Rails.logger.error "WorkOrderService: 无法#{action_name}工单 ##{@work_order.id}. 错误: #{@work_order.errors.full_messages.join(", ")}"
      false
    end
  end
  
  # Assign shared attributes from params to the work order
  def assign_shared_attributes(params)
    # Define attributes that are common and can be assigned directly.
    # problem_type/problem_description are often ID-based.
    # remark, processing_opinion, audit_comment are direct text fields.
    # audit_date is usually set by callbacks.
    
    shared_attr_keys = [
      :remark, :processing_opinion, :audit_comment, 
      :problem_type_id, :problem_description_id
    ]
    
    # Slice only the attributes present in params to avoid mass assignment issues with nil if not careful
    attrs_to_assign = params.slice(*shared_attr_keys.select { |key| params.key?(key) })
    
    @work_order.assign_attributes(attrs_to_assign) if attrs_to_assign.present?
  end

  def process_work_order
    case @work_order
    when AuditWorkOrder
      process_audit_work_order
    when CommunicationWorkOrder
      process_communication_work_order
    end
  end

  def process_audit_work_order
    # 处理审核工单
    if @work_order.audit_result == AuditWorkOrder::AUDIT_RESULT_PASS
      @work_order.update(status: :completed)
    elsif @work_order.audit_result == AuditWorkOrder::AUDIT_RESULT_FAIL
      @work_order.update(status: :rejected)
    end
  end

  def process_communication_work_order
    # 处理沟通工单
    if @work_order.resolution_summary.present?
      @work_order.update(status: :completed)
    end
  end
end 