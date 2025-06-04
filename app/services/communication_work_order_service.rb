# app/services/communication_work_order_service.rb
class CommunicationWorkOrderService < WorkOrderService
  def initialize(communication_work_order, current_admin_user)
    Rails.logger.debug "CommunicationWorkOrderService#initialize: 初始化服务，工单: #{communication_work_order.inspect}"
    super(communication_work_order, current_admin_user)
    # @work_order will be the communication_work_order instance from super
    # and is accessible as @work_order or work_order (attr_reader from parent)
    Rails.logger.debug "CommunicationWorkOrderService#initialize: 初始化完成"
  end

  # 重写 update 方法，添加更多日志
  def update(params = {})
    Rails.logger.debug "CommunicationWorkOrderService#update: 开始更新工单 ##{@work_order.id}, 当前状态: #{@work_order.status}"
    Rails.logger.debug "CommunicationWorkOrderService#update: 参数: #{params.inspect}"
    
    # 调用父类方法
    result = super(params)
    
    Rails.logger.debug "CommunicationWorkOrderService#update: 更新结果: #{result}"
    Rails.logger.debug "CommunicationWorkOrderService#update: 更新后工单状态: #{@work_order.status}"
    Rails.logger.debug "CommunicationWorkOrderService#update: 更新后错误信息: #{@work_order.errors.full_messages.inspect}" unless result
    
    result
  end

  # The errors method can also be inherited if work_order.errors is sufficient,
  # or customize if needed.
  # def errors
  #   @work_order.errors
  # end
end