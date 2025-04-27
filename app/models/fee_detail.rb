class FeeDetail < ApplicationRecord
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
  belongs_to :reimbursement, foreign_key: 'document_number', primary_key: 'invoice_number', optional: true
  has_many :fee_detail_selections, dependent: :destroy
  has_many :audit_work_orders, through: :fee_detail_selections
  has_many :communication_work_orders, through: :fee_detail_selections

  # 验证
  validates :document_number, presence: true
  validates :fee_type, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :verification_status, presence: true, inclusion: { in: VERIFICATION_STATUSES }

  # 范围
  scope :pending, -> { where(verification_status: VERIFICATION_STATUS_PENDING) }
  scope :verified, -> { where(verification_status: VERIFICATION_STATUS_VERIFIED) }
  scope :rejected, -> { where(verification_status: VERIFICATION_STATUS_REJECTED) }
  scope :problematic, -> { where(verification_status: VERIFICATION_STATUS_PROBLEMATIC) }
  scope :not_verified, -> { where.not(verification_status: VERIFICATION_STATUS_VERIFIED) }
  scope :not_rejected, -> { where.not(verification_status: VERIFICATION_STATUS_REJECTED) }
  scope :requiring_action, -> { where(verification_status: [VERIFICATION_STATUS_PENDING, VERIFICATION_STATUS_PROBLEMATIC]) }

  # 方法
  def mark_as_verified
    update(verification_status: VERIFICATION_STATUS_VERIFIED)
  end

  def mark_as_rejected
    update(verification_status: VERIFICATION_STATUS_REJECTED)
  end

  def mark_as_problematic
    update(verification_status: VERIFICATION_STATUS_PROBLEMATIC)
  end

  def mark_as_pending
    update(verification_status: VERIFICATION_STATUS_PENDING)
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

  def requires_action?
    pending? || problematic?
  end

  def latest_audit_selection
    fee_detail_selections.joins(:audit_work_order).order('audit_work_orders.created_at DESC').first
  end

  def latest_communication_selection
    fee_detail_selections.joins(:communication_work_order).order('communication_work_orders.created_at DESC').first
  end

  # ActiveAdmin配置
  def self.ransackable_attributes(auth_object = nil)
    %w[id document_number fee_type amount currency fee_date payment_method verification_status created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[reimbursement fee_detail_selections audit_work_orders communication_work_orders]
  end
end