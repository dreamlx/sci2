# app/models/work_order_status_change.rb
class WorkOrderStatusChange < ApplicationRecord
  # 关联
  belongs_to :work_order, polymorphic: true
  belongs_to :changer, class_name: 'AdminUser', foreign_key: 'changer_id', optional: true
  
  # 验证
  validates :to_status, presence: true
  validates :changed_at, presence: true
  
  # 范围查询
  scope :recent, -> { order(changed_at: :desc) }
  scope :for_audit_work_orders, -> { where(work_order_type: 'AuditWorkOrder') }
  scope :for_communication_work_orders, -> { where(work_order_type: 'CommunicationWorkOrder') }
  scope :for_express_receipt_work_orders, -> { where(work_order_type: 'ExpressReceiptWorkOrder') }
  
  # 便捷方法
  def status_change_description
    if from_status.present?
      "从 #{from_status} 变更为 #{to_status}"
    else
      "初始状态设置为 #{to_status}"
    end
  end
  
  # ActiveAdmin配置
  def self.ransackable_attributes(auth_object = nil)
    %w[id work_order_type work_order_id from_status to_status changed_at changed_by created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[work_order changer]
  end
end