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
  def self.subclass_ransackable_attributes
    # 继承的通用字段 + 特定字段
    %w[tracking_number received_at courier_name]
  end
  
  def self.subclass_ransackable_associations
    [] # 无特定关联
  end
  
  private
  
  def set_default_status
    self.status ||= 'completed'
  end
end