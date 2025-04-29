# app/models/fee_detail_selection.rb
class FeeDetailSelection < ApplicationRecord
  # 关联
  belongs_to :fee_detail
  belongs_to :work_order, polymorphic: true
  belongs_to :verifier, class_name: 'AdminUser', foreign_key: 'verifier_id', optional: true
  
  # 验证
  validates :verification_status, presence: true, inclusion: { in: %w[pending problematic verified] }
  validates :fee_detail_id, uniqueness: { scope: [:work_order_id, :work_order_type] }
  
  # 回调
  after_save :update_fee_detail_status, if: :saved_change_to_verification_status?
  
  private
  
  def update_fee_detail_status
    # 仅当状态变更为 verified 或 problematic 时更新费用明细状态
    return unless %w[verified problematic].include?(verification_status)
    
    # 更新费用明细状态
    fee_detail.update(verification_status: verification_status)
  end
  
  # ActiveAdmin配置
  def self.ransackable_attributes(auth_object = nil)
    %w[id fee_detail_id work_order_id work_order_type verification_status verification_comment verified_by verified_at created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[fee_detail work_order]
  end
end