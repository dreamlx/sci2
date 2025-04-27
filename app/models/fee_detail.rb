# app/models/fee_detail.rb
class FeeDetail < ApplicationRecord
  # 关联
  belongs_to :reimbursement, foreign_key: 'document_number', primary_key: 'invoice_number'
  has_many :fee_detail_selections, dependent: :destroy
  has_many :work_orders, through: :fee_detail_selections
  
  # 验证
  validates :document_number, presence: true
  validates :verification_status, presence: true, inclusion: { in: %w[pending problematic verified] }
  
  # 范围查询
  scope :pending, -> { where(verification_status: 'pending') }
  scope :problematic, -> { where(verification_status: 'problematic') }
  scope :verified, -> { where(verification_status: 'verified') }
  
  # 回调
  after_save :update_reimbursement_status, if: :saved_change_to_verification_status?
  
  private
  
  def update_reimbursement_status
    reimbursement.update_status_based_on_fee_details! if reimbursement.present?
  end
end