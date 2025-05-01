# app/models/fee_detail_selection.rb
class FeeDetailSelection < ApplicationRecord
  # 关联
  belongs_to :fee_detail
  belongs_to :work_order, polymorphic: true
  belongs_to :verifier, class_name: 'AdminUser', foreign_key: 'verifier_id', optional: true
  
  # 验证
  validates :fee_detail_id, presence: true
  validates :work_order_id, presence: true
  validates :work_order_type, presence: true
  
  # 使用标准Rails唯一性验证
  validates :fee_detail_id, uniqueness: {
    scope: [:work_order_id, :work_order_type],
    message: "已被选择"
  }
  
  # ActiveAdmin配置
  def self.ransackable_attributes(auth_object = nil)
    %w[id fee_detail_id work_order_id work_order_type verification_comment verifier_id verified_at created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[fee_detail work_order]
  end
end