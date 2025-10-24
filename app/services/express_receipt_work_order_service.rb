# app/services/express_receipt_work_order_service.rb
class ExpressReceiptWorkOrderService
  def initialize(express_receipt_work_order, current_admin_user)
    unless express_receipt_work_order.is_a?(ExpressReceiptWorkOrder)
      raise ArgumentError,
            'Expected ExpressReceiptWorkOrder'
    end

    @express_receipt_work_order = express_receipt_work_order
    @current_admin_user = current_admin_user
    Current.admin_user = current_admin_user
  end

  # 快递收单工单通常是自动完成的，因此不需要状态转换方法
  # 但为了保持接口一致性，我们提供一些基本方法

  # 获取工单信息
  def work_order
    @express_receipt_work_order
  end

  # 获取关联的报销单
  def reimbursement
    @express_receipt_work_order.reimbursement
  end

  # 获取快递单号
  def tracking_number
    @express_receipt_work_order.tracking_number
  end

  # 获取收单时间
  def received_at
    @express_receipt_work_order.received_at
  end

  # 更新快递信息
  def update_tracking_info(params)
    @express_receipt_work_order.update(params.slice(:tracking_number, :courier_name, :received_at))
  end
end
