class FeeDetailSelection < ApplicationRecord
  # 常量
  VERIFICATION_STATUS_PENDING = 'pending'
  VERIFICATION_STATUS_VERIFIED = 'verified'
  VERIFICATION_STATUS_REJECTED = 'rejected'
  VERIFICATION_STATUS_PROBLEMATIC = 'problematic'

  VERIFICATION_STATUSES = [
    VERIFICATION_STATUS_PENDING,
    VERIFICATION_STATUS_VERIFIED,
    VERIFICATION_STATUS_REJECTED,
    VERIFICATION_STATUS_PROBLEMATIC
  ]

  # 关联
  belongs_to :fee_detail
  belongs_to :audit_work_order, optional: true
  belongs_to :communication_work_order, optional: true

  # 验证
  validates :verification_status, presence: true, inclusion: { in: VERIFICATION_STATUSES }
  validates :fee_detail_id, uniqueness: { scope: :audit_work_order_id }, if: :audit_work_order_id?
  validates :fee_detail_id, uniqueness: { scope: :communication_work_order_id }, if: :communication_work_order_id?
  validate :ensure_one_work_order_association
  validate :ensure_unique_fee_detail_for_work_order

  # 范围
  scope :pending, -> { where(verification_status: VERIFICATION_STATUS_PENDING) }
  scope :verified, -> { where(verification_status: VERIFICATION_STATUS_VERIFIED) }
  scope :rejected, -> { where(verification_status: VERIFICATION_STATUS_REJECTED) }
  scope :problematic, -> { where(verification_status: VERIFICATION_STATUS_PROBLEMATIC) }
  scope :for_audit_work_orders, -> { where.not(audit_work_order_id: nil) }
  scope :for_communication_work_orders, -> { where.not(communication_work_order_id: nil) }

  # 方法
  def mark_as_verified(comment = nil, verified_by = nil)
    update(
      verification_status: VERIFICATION_STATUS_VERIFIED,
      verification_comment: comment,
      verified_by: verified_by,
      verified_at: Time.current
    )
  end

  def mark_as_rejected(comment = nil, verified_by = nil)
    update(
      verification_status: VERIFICATION_STATUS_REJECTED,
      verification_comment: comment,
      verified_by: verified_by,
      verified_at: Time.current
    )
  end

  def mark_as_problematic(comment = nil, verified_by = nil)
    update(
      verification_status: VERIFICATION_STATUS_PROBLEMATIC,
      verification_comment: comment,
      verified_by: verified_by,
      verified_at: Time.current
    )
  end

  def verified?
    verification_status == VERIFICATION_STATUS_VERIFIED
  end

  def rejected?
    verification_status == VERIFICATION_STATUS_REJECTED
  end

  def problematic?
    verification_status == VERIFICATION_STATUS_PROBLEMATIC
  end

  def pending?
    verification_status == VERIFICATION_STATUS_PENDING
  end

  def work_order
    audit_work_order || communication_work_order
  end

  def work_order_type
    if audit_work_order_id.present?
      'audit'
    elsif communication_work_order_id.present?
      'communication'
    else
      nil
    end
  end

  private

  def ensure_one_work_order_association
    if audit_work_order_id.blank? && communication_work_order_id.blank?
      errors.add(:base, "必须关联到审核工单或沟通工单")
    end

    if audit_work_order_id.present? && communication_work_order_id.present?
      errors.add(:base, "不能同时关联到审核工单和沟通工单")
    end
  end
  
  def ensure_unique_fee_detail_for_work_order
    return unless fee_detail_id.present?
    
    if audit_work_order_id.present?
      duplicates = self.class.where(fee_detail_id: fee_detail_id, audit_work_order_id: audit_work_order_id)
      duplicates = duplicates.where.not(id: id) if persisted?
      errors.add(:fee_detail_id, "已经被关联到该审核工单") if duplicates.exists?
    end
    
    if communication_work_order_id.present?
      duplicates = self.class.where(fee_detail_id: fee_detail_id, communication_work_order_id: communication_work_order_id)
      duplicates = duplicates.where.not(id: id) if persisted?
      errors.add(:fee_detail_id, "已经被关联到该沟通工单") if duplicates.exists?
    end
  end

  # ActiveAdmin配置
  def self.ransackable_attributes(auth_object = nil)
    %w[id fee_detail_id audit_work_order_id communication_work_order_id verification_status verification_comment verified_by verified_at created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[fee_detail audit_work_order communication_work_order]
  end
end