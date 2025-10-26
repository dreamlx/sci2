# app/models/audit_work_order.rb
# frozen_string_literal: true

class AuditWorkOrder < WorkOrder
  include WorkOrderStatusTraits

  # 定义审核工单的状态特性
  define_status_traits(
    available_statuses: %w[pending processing approved rejected],
    initial_status: 'pending',
    final_statuses: %w[approved rejected],
    manual_status_only: true
  )

  # 特有属性 (这些字段也应存在于 work_orders 表中, 对其他 type 的工单为 null)
  # :audit_result (string, e.g., 'approved', 'rejected')
  # :audit_comment (text)
  # :audit_date (datetime)
  # :vat_verified (boolean)

  # 特有验证
  validates :audit_result, inclusion: { in: %w[approved rejected] }, allow_nil: true # 允许在处理过程中为 nil
  # validates :audit_comment, presence: true, if: -> { audit_result == 'rejected' }
  # validates :audit_date, presence: true, if: -> { audit_result.present? }

  # 回调
  after_save :sync_audit_result_with_status, if: -> { status_changed? && persisted? }

  # ActiveAdmin 支持
  def self.ransackable_attributes(auth_object = nil)
    super + %w[audit_result audit_comment audit_date vat_verified]
  end

  def self.ransackable_associations(auth_object = nil)
    super + [] # 如果有特有可搜索关联，在此添加
  end

  private

  # 同步状态和审核结果
  def sync_audit_result_with_status
    case status
    when 'approved'
      self.audit_result = 'approved'
      self.audit_date = Time.current
    when 'rejected'
      self.audit_result = 'rejected'
      self.audit_date = Time.current
    end

    # 避免触发无限循环
    self.class.skip_callback(:save, :after, :sync_audit_result_with_status)
    save
    self.class.set_callback(:save, :after, :sync_audit_result_with_status, if: -> { status_changed? && persisted? })
  end

  # 可选：特有方法
  # def vat_not_verified?
  #   !vat_verified
  # end
end
