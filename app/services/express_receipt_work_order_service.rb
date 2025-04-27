class ExpressReceiptWorkOrderService
  def initialize(work_order, admin_user)
    @work_order = work_order
    @admin_user = admin_user
  end

  def process
    ActiveRecord::Base.transaction do
      @work_order.process!
      record_operation_history('process')
      true
    rescue => e
      Rails.logger.error "Failed to process work order: #{e.message}"
      false
    end
  end

  def complete
    ActiveRecord::Base.transaction do
      @work_order.complete!
      record_operation_history('complete')
      true
    rescue => e
      Rails.logger.error "Failed to complete work order: #{e.message}"
      false
    end
  end

  private

  def record_operation_history(operation_type)
    OperationHistory.create!(
      document_number: @work_order.reimbursement.invoice_number,
      operation_type: operation_type,
      operation_time: Time.current,
      operator: @admin_user.email,
      notes: "快递收单工单 #{@work_order.id} 状态变更为 #{@work_order.status}"
    )
  end
end