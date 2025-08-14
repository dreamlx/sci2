# app/services/fee_detail_status_service.rb
class FeeDetailStatusService
  def initialize(fee_detail_ids = nil)
    @fee_detail_ids = Array(fee_detail_ids)
  end
  
  # Update status for specific fee details
  def update_status
    fee_details = @fee_detail_ids.present? ? 
      FeeDetail.where(id: @fee_detail_ids) : 
      FeeDetail.all
      
    fee_details.find_each do |fee_detail|
      update_fee_detail_status(fee_detail)
    end
  end
  
  # Update status for fee details related to a specific work order
  def update_status_for_work_order(work_order)
    # Get all fee details associated with this work order - 简化版本
    fee_detail_ids = work_order.work_order_fee_details.pluck(:fee_detail_id)
    
    # Update their status
    FeeDetail.where(id: fee_detail_ids).find_each do |fee_detail|
      update_fee_detail_status(fee_detail)
    end
  end
  
  private
  
  def update_fee_detail_status(fee_detail)
    # 添加调试日志
    Rails.logger.debug "FeeDetailStatusService#update_fee_detail_status: 开始更新费用明细 ##{fee_detail.id}, 当前状态: #{fee_detail.verification_status}"
    
    # Get the latest work order associated with this fee detail
    latest_work_order = get_latest_work_order(fee_detail)
    
    if latest_work_order.nil?
      Rails.logger.debug "FeeDetailStatusService#update_fee_detail_status: 没有关联的工单，保持或设置为 pending"
      # If no work orders, keep or set to pending
      unless fee_detail.verification_status == "pending"
        fee_detail.update(verification_status: "pending")
        Rails.logger.debug "FeeDetailStatusService#update_fee_detail_status: 更新状态为 pending"
      end
      return
    end
    
    Rails.logger.debug "FeeDetailStatusService#update_fee_detail_status: 最新关联工单 ##{latest_work_order.id}, 类型: #{latest_work_order.type}, 状态: #{latest_work_order.status}"
    
    # Apply the "latest work order decides" principle
    new_status = determine_status_from_work_order(latest_work_order)
    Rails.logger.debug "FeeDetailStatusService#update_fee_detail_status: 根据工单状态确定的新状态: #{new_status}"
    
    # Update only if status has changed
    if fee_detail.verification_status != new_status
      Rails.logger.debug "FeeDetailStatusService#update_fee_detail_status: 状态需要更新，从 #{fee_detail.verification_status} 到 #{new_status}"
      result = fee_detail.update(verification_status: new_status)
      Rails.logger.debug "FeeDetailStatusService#update_fee_detail_status: 更新结果: #{result}, 错误: #{fee_detail.errors.full_messages.join(', ')}"
    else
      Rails.logger.debug "FeeDetailStatusService#update_fee_detail_status: 状态未变更，保持为 #{fee_detail.verification_status}"
    end
  end
  
  def get_latest_work_order(fee_detail)
    # 排除沟通工单，只考虑审核工单来决定状态
    fee_detail.work_orders
               .where.not(type: 'CommunicationWorkOrder')
               .order(updated_at: :desc)
               .first
  end
  
  def determine_status_from_work_order(work_order)
    # Skip express receipt work orders as they don't affect verification status
    return "pending" if work_order.is_a?(ExpressReceiptWorkOrder)
    
    # Skip communication work orders as they don't affect verification status
    return "pending" if work_order.is_a?(CommunicationWorkOrder)
    
    case work_order.status
    when "approved"
      "verified"
    when "rejected"
      "problematic"
    else
      # For pending or other statuses, keep as pending
      "pending"
    end
  end
end