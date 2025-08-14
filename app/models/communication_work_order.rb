# app/models/communication_work_order.rb
# frozen_string_literal: true

class CommunicationWorkOrder < WorkOrder
  # 沟通工单专注于记录电话沟通，不影响费用明细状态
  # 字段：communication_method, audit_comment
  
  # 简化验证 - 只验证沟通必要信息
  validates :audit_comment, presence: true, length: { minimum: 10, message: "沟通内容至少需要10个字符" }
  validates :communication_method, presence: true
  
  # 移除费用相关验证和关联
  # 移除: validate :has_problem_types
  # 移除: has_many :communication_records
  # 移除: belongs_to :audit_work_order
  
  # 自动完成逻辑 - 提交后自动设置为完成状态
  after_create :mark_as_completed
  
  # ActiveAdmin 支持 - 简化搜索属性
  def self.ransackable_attributes(auth_object = nil)
    super + %w[communication_method]
  end

  def self.ransackable_associations(auth_object = nil)
    super
  end

  private

  # 创建后自动标记为完成
  def mark_as_completed
    update_column(:status, 'completed')
  end
end