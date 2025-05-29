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
    # Get all fee details associated with this work order
    fee_detail_ids = WorkOrderFeeDetail.where(
      work_order_id: work_order.id,
      work_order_type: work_order.type
    ).pluck(:fee_detail_id)
    
    # Update their status
    FeeDetail.where(id: fee_detail_ids).find_each do |fee_detail|
      update_fee_detail_status(fee_detail)
    end
  end
  
  private
  
  def update_fee_detail_status(fee_detail)
    # Get the latest work order associated with this fee detail
    latest_work_order = get_latest_work_order(fee_detail)
    
    if latest_work_order.nil?
      # If no work orders, keep or set to pending
      fee_detail.update(verification_status: "pending") unless fee_detail.verification_status == "pending"
      return
    end
    
    # Apply the "latest work order decides" principle
    new_status = determine_status_from_work_order(latest_work_order)
    
    # Update only if status has changed
    if fee_detail.verification_status != new_status
      fee_detail.update(verification_status: new_status)
    end
  end
  
  def get_latest_work_order(fee_detail)
    # Get all work orders associated with this fee detail
    work_order_ids_with_types = WorkOrderFeeDetail.where(fee_detail_id: fee_detail.id)
                                                 .pluck(:work_order_id, :work_order_type)
    
    return nil if work_order_ids_with_types.empty?
    
    # Find the latest work order by updated_at timestamp
    latest_work_order = nil
    latest_updated_at = nil
    
    work_order_ids_with_types.each do |work_order_id, work_order_type|
      work_order = work_order_type.constantize.find_by(id: work_order_id)
      next unless work_order
      
      if latest_updated_at.nil? || work_order.updated_at > latest_updated_at
        latest_work_order = work_order
        latest_updated_at = work_order.updated_at
      end
    end
    
    latest_work_order
  end
  
  def determine_status_from_work_order(work_order)
    # Skip express receipt work orders as they don't affect verification status
    return "pending" if work_order.is_a?(ExpressReceiptWorkOrder)
    
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