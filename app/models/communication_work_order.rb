# app/models/communication_work_order.rb
# frozen_string_literal: true

class CommunicationWorkOrder < WorkOrder
  # 特有属性 (这些字段也应存在于 work_orders 表中, 对其他 type 的工单为 null)
  # :audit_work_order_id (integer, foreign key to link to an AuditWorkOrder if applicable)
  # :communication_method (string)
  # :initiator_role (string)
  # :resolution_summary (text)

  # 关联
  has_many :communication_records, dependent: :destroy

  # 特有关联
  belongs_to :audit_work_order, optional: true # 一个沟通工单可能关联一个审核工单

  # ActiveAdmin 支持
  def self.ransackable_attributes(auth_object = nil)
    super + %w[audit_work_order_id communication_method initiator_role resolution_summary]
  end

  def self.ransackable_associations(auth_object = nil)
    super + %w[audit_work_order communication_records] # 如果 CommunicationRecord 需要被搜索
  end

  private

end