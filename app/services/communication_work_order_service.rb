# app/services/communication_work_order_service.rb
# frozen_string_literal: true

class CommunicationWorkOrderService < WorkOrderService
  def initialize(communication_work_order, current_admin_user)
    super
    @communication_work_order = communication_work_order
  end

  # The generic WorkOrderService#approve and WorkOrderService#reject methods
  # will now be used, which call the state machine events.
  # Specific logic for CommunicationWorkOrder, if any beyond attribute assignment
  # (handled by assign_shared_attributes in parent), can be added here or by overriding.

  # The update method from WorkOrderService is now more generic.
  # If CommunicationWorkOrder needs specific update logic beyond what WorkOrderService#update provides
  # (which is assign_shared_attributes + save), it can be overridden here.

  # 重写 update 方法，添加更多日志
  def update(params = {})
    Rails.logger.debug "CommunicationWorkOrderService#update: 开始更新工单 ##{@work_order.id}, 当前状态: #{@work_order.status}"
    Rails.logger.debug "CommunicationWorkOrderService#update: 参数: #{params.inspect}"

    # 调用父类方法
    result = super

    Rails.logger.debug "CommunicationWorkOrderService#update: 更新结果: #{result}"
    Rails.logger.debug "CommunicationWorkOrderService#update: 更新后工单状态: #{@work_order.status}"
    unless result
      Rails.logger.debug "CommunicationWorkOrderService#update: 更新后错误信息: #{@work_order.errors.full_messages.inspect}"
    end

    result
  end
end
