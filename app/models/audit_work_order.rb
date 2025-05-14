# app/models/audit_work_order.rb
# frozen_string_literal: true

class AuditWorkOrder < WorkOrder
  # 特有属性 (这些字段也应存在于 work_orders 表中, 对其他 type 的工单为 null)
  # :audit_result (string, e.g., 'approved', 'rejected')
  # :audit_comment (text)
  # :audit_date (datetime)
  # :vat_verified (boolean)

  # 特有验证
  validates :audit_result, inclusion: { in: %w[approved rejected] }, allow_nil: true # 允许在处理过程中为 nil
  # validates :audit_comment, presence: true, if: -> { audit_result == 'rejected' }
  # validates :audit_date, presence: true, if: -> { audit_result.present? }

  # 子类可以按需扩展 AASM 状态机，例如：
  # aasm column: :status, whiny_transitions: false do
  #   state :specific_audit_state
  #   event :specific_audit_event do
  #     transitions from: :processing, to: :specific_audit_state
  #   end
  # end

  # ActiveAdmin 支持
  def self.ransackable_attributes(auth_object = nil)
    super + %w[audit_result audit_comment audit_date vat_verified]
  end

  def self.ransackable_associations(auth_object = nil)
    super + [] # 如果有特有可搜索关联，在此添加
  end

  private

  def processing_opinion_pass_or_cannot_pass?
    processing_opinion.in?(['可以通过', '无法通过'])
  end

  def audit_result_changed?
    resolution_changed?
  end

  # 可选：特有方法
  # def vat_not_verified?
  #   !vat_verified
  # end
end