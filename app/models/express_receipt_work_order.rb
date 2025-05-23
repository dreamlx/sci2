# app/models/express_receipt_work_order.rb
class ExpressReceiptWorkOrder < WorkOrder
  # 验证
  validates :tracking_number, presence: true
  validates :status, inclusion: { in: ['completed'] } # 仅允许的状态
  
  # 可选的其他验证
  validates :received_at, presence: true
  
  # 回调
  before_validation :set_default_status, on: :create
  
  # 业务方法
  def mark_reimbursement_as_received
    reimbursement.mark_as_received(received_at || Time.current)
  end
  
  # ActiveAdmin 支持
  def self.ransackable_attributes(auth_object = nil)
    # 调用父类并添加 ExpressReceiptWorkOrder 特有的
    (super + %w[tracking_number courier_name received_at]).uniq
  end
  
  def self.ransackable_associations(auth_object = nil)
    # 如果 ExpressReceiptWorkOrder 不应该搜索 fee_details 和 work_order_fee_details
    # 确保它们不包含在最终的列表中。
    # 如果父类 (WorkOrder) 的 ransackable_associations 包含了它们，你需要排除掉：
    # (super - %w[fee_details work_order_fee_details]).uniq
    # 或者，如果父类不包含它们，或者你想完全定义 ExpressReceiptWorkOrder 的可搜索关联:
    %w[reimbursement creator work_order_status_changes] # 只包含对 ExpressReceiptWorkOrder 明确有意义的
  end
  
  private
  
  def set_default_status
    self.status ||= 'completed'
  end
end