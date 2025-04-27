class WorkOrderStatusChange < ApplicationRecord
  # 关联
  belongs_to :work_order, polymorphic: true, optional: true

  # 验证
  validates :work_order_type, presence: true
  validates :work_order_id, presence: true
  validates :to_status, presence: true
  validates :changed_at, presence: true

  # 范围
  scope :for_express_receipt_work_orders, -> { where(work_order_type: 'express_receipt') }
  scope :for_audit_work_orders, -> { where(work_order_type: 'audit') }
  scope :for_communication_work_orders, -> { where(work_order_type: 'communication') }
  scope :recent, -> { order(changed_at: :desc) }
  scope :by_changed_by, ->(user_id) { where(changed_by: user_id) }

  # 方法
  def work_order_object
    case work_order_type
    when 'express_receipt'
      ExpressReceiptWorkOrder.find_by(id: work_order_id)
    when 'audit'
      AuditWorkOrder.find_by(id: work_order_id)
    when 'communication'
      CommunicationWorkOrder.find_by(id: work_order_id)
    end
  end

  def changed_by_user
    AdminUser.find_by(id: changed_by) if changed_by.present?
  end

  def status_change_description
    "从 #{from_status || '(初始状态)'} 变更为 #{to_status}"
  end

  # ActiveAdmin配置
  def self.ransackable_attributes(auth_object = nil)
    %w[id work_order_type work_order_id from_status to_status changed_at changed_by reason created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[work_order]
  end
end