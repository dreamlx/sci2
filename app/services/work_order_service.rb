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

  # Approve work order (Status change handled by model callback based on processing_opinion/status)
  def approve(params = {})
    assign_shared_attributes(params.merge(processing_opinion: '审核通过')) # Set opinion for callback

    # Common comment field validation remains
    comment = params[:audit_comment]
    if comment.blank? && (@work_order.is_a?(AuditWorkOrder) || @work_order.is_a?(CommunicationWorkOrder))
      @work_order.errors.add(:audit_comment, "不能为空，请填写处理意见。")
      return false
    end
    # audit_comment is assigned via assign_shared_attributes
    
    save_work_order("批准")
  rescue => e # Keep generic rescue
    @work_order.errors.add(:base, "无法批准: #{e.message}")
    false
  end

  # Reject work order (Status change handled by model callback based on processing_opinion/status)
  def reject(params = {})
    assign_shared_attributes(params.merge(processing_opinion: '无法通过')) # Set opinion for callback
    
    # comment validation remains
    comment = params[:audit_comment]
    if comment.blank? && (@work_order.is_a?(AuditWorkOrder) || @work_order.is_a?(CommunicationWorkOrder))
      @work_order.errors.add(:audit_comment, "不能为空，请填写处理意见。")
      return false
    end 
    # audit_comment is assigned via assign_shared_attributes

    # Ensure required fields check remains (now based on status='rejected' in model validation)
    if @work_order.is_a?(AuditWorkOrder) || @work_order.is_a?(CommunicationWorkOrder)
      if params[:problem_type_id].blank? && @work_order.problem_type_id.blank?
        @work_order.errors.add(:problem_type_id, "不能为空")
      end
      if params[:problem_description_id].blank? && @work_order.problem_description_id.blank?
        @work_order.errors.add(:problem_description_id, "不能为空")
      end
      return false if @work_order.errors.any?
    end

    save_work_order("拒绝")
  rescue => e # Keep generic rescue
    @work_order.errors.add(:base, "无法拒绝: #{e.message}")
    false
  end

  # General update method, driven by processing_opinion which triggers status callback
  def update(params = {})
    assign_shared_attributes(params)
    
    # Remove resolution calculation logic
    # The model callback `set_status_based_on_processing_opinion` handles status changes
    
    # Just save the work order; callbacks will handle status based on opinion
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
end 