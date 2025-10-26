# app/models/express_receipt_work_order.rb
class ExpressReceiptWorkOrder < WorkOrder
  include WorkOrderStatusTraits

  # 定义快递收单工单的状态特性 - 总是完成状态
  define_status_traits(
    available_statuses: %w[completed],
    initial_status: 'completed',
    final_statuses: %w[completed],
    always_completed: true
  )

  # 验证
  validates :tracking_number, presence: true
  validates :status, inclusion: { in: ['completed'] } # 仅允许的状态
  validates :received_at, presence: true
  validates :filling_id, presence: true, uniqueness: true, format: { with: /\A\d{10}\z/ }

  # 回调
  before_validation :set_default_status, on: :create
  before_validation :generate_filling_id, on: :create

  # 业务方法
  def mark_reimbursement_as_received
    reimbursement.mark_as_received(received_at || Time.current)
  end

  # ActiveAdmin 支持
  def self.ransackable_attributes(auth_object = nil)
    # 调用父类并添加 ExpressReceiptWorkOrder 特有的
    (super + %w[tracking_number courier_name received_at filling_id]).uniq
  end

  def self.ransackable_associations(_auth_object = nil)
    # 如果 ExpressReceiptWorkOrder 不应该搜索 fee_details 和 work_order_fee_details
    # 确保它们不包含在最终的列表中。
    # 如果父类 (WorkOrder) 的 ransackable_associations 包含了它们，你需要排除掉：
    # (super - %w[fee_details work_order_fee_details]).uniq
    # 或者，如果父类不包含它们，或者你想完全定义 ExpressReceiptWorkOrder 的可搜索关联:
    %w[reimbursement creator work_order_status_changes] # 只包含对 ExpressReceiptWorkOrder 明确有意义的
  end

  private

  def set_default_status
    self.status = 'completed' # Always set to completed, don't use ||= because state machine sets initial value
  end

  def generate_filling_id
    return if filling_id.present? # Don't regenerate if already set

    self.filling_id = FillingIdGenerator.generate(received_at)
  end
end
