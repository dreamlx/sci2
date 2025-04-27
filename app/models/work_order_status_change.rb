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
  
  # 便捷方法
  def status_change_description
    if from_status.present?
      "从 #{from_status} 变更为 #{to_status}"
    else
      "初始状态设置为 #{to_status}"
    end
  end
end