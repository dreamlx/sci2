class FeeDetail < ApplicationRecord
  # Constants
  VERIFICATION_STATUS_PENDING = 'pending'.freeze
  VERIFICATION_STATUS_PROBLEMATIC = 'problematic'.freeze
  VERIFICATION_STATUS_VERIFIED = 'verified'.freeze
  
  VERIFICATION_STATUSES = [
    VERIFICATION_STATUS_PENDING,
    VERIFICATION_STATUS_PROBLEMATIC,
    VERIFICATION_STATUS_VERIFIED
  ].freeze
  
  # Associations
  belongs_to :reimbursement, foreign_key: 'document_number', primary_key: 'invoice_number'
  has_many :work_order_fee_details, dependent: :destroy
  has_many :work_orders, through: :work_order_fee_details
  
  # Validations
  validates :document_number, presence: true
  validates :verification_status, inclusion: { in: VERIFICATION_STATUSES }
  validates :external_fee_id, uniqueness: true, allow_nil: true
  validates :amount, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  
  # Callbacks
  after_save :update_reimbursement_status, if: -> { saved_change_to_verification_status? }
  
  # Scopes
  scope :pending, -> { where(verification_status: VERIFICATION_STATUS_PENDING) }
  scope :problematic, -> { where(verification_status: VERIFICATION_STATUS_PROBLEMATIC) }
  scope :verified, -> { where(verification_status: VERIFICATION_STATUS_VERIFIED) }
  scope :by_document, ->(document_number) { where(document_number: document_number) }
  
  # Class methods for scopes (for shoulda-matchers compatibility)
  def self.pending
    where(verification_status: VERIFICATION_STATUS_PENDING)
  end
  
  def self.problematic
    where(verification_status: VERIFICATION_STATUS_PROBLEMATIC)
  end
  
  def self.verified
    where(verification_status: VERIFICATION_STATUS_VERIFIED)
  end
  
  def self.by_document(document_number)
    where(document_number: document_number)
  end
  
  # ActiveAdmin configuration
  def self.ransackable_attributes(auth_object = nil)
    %w[id document_number fee_type amount fee_date verification_status month_belonging 
       first_submission_date created_at updated_at notes external_fee_id 
       plan_or_pre_application product flex_field_11 expense_corresponding_plan 
       expense_associated_application flex_field_6 flex_field_7]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[reimbursement work_order_fee_details work_orders]
  end
  
  # Instance methods
  
  # Get the latest work order associated with this fee detail - 简化版本
  def latest_work_order
    # 直接使用关联获取最新的工单（按更新时间排序）
    work_orders.order(updated_at: :desc).first
  end
  
  # Alias for compatibility with existing code
  alias_method :latest_associated_work_order, :latest_work_order
  
  # Get all work orders that affect this fee detail's status, ordered by recency
  def affecting_work_orders
    work_orders.order(updated_at: :desc)
  end
  
  # Check if this fee detail is verified
  def verified?
    verification_status == VERIFICATION_STATUS_VERIFIED
  end
  
  # Check if this fee detail has problems
  def problematic?
    verification_status == VERIFICATION_STATUS_PROBLEMATIC
  end
  
  # Check if this fee detail is pending verification
  def pending?
    verification_status == VERIFICATION_STATUS_PENDING
  end
  
  # Update the verification status based on the latest work order
  def update_verification_status
    FeeDetailStatusService.new([id]).update_status
  end
  
  # Get all work orders that have affected this fee detail, ordered by recency
  def work_order_history
    # 直接使用关联获取所有工单，按更新时间排序
    work_orders.order(updated_at: :desc)
  end
  
  # Get the status of the latest work order
  def latest_work_order_status
    latest = latest_work_order
    latest&.status
  end
  
  # Check if this fee detail has been approved by any work order
  def approved_by_any_work_order?
    work_orders.where(status: WorkOrder::STATUS_APPROVED).exists?
  end
  
  # Check if this fee detail has been rejected by any work order
  def rejected_by_any_work_order?
    work_orders.where(status: WorkOrder::STATUS_REJECTED).exists?
  end
  
  # Check if this fee detail has been approved by the latest work order
  def approved_by_latest_work_order?
    latest_work_order_status == WorkOrder::STATUS_APPROVED
  end
  
  # Check if this fee detail has been rejected by the latest work order
  def rejected_by_latest_work_order?
    latest_work_order_status == WorkOrder::STATUS_REJECTED
  end
  
  # Mark this fee detail as verified
  def mark_as_verified
    update(verification_status: VERIFICATION_STATUS_VERIFIED)
  end
  
  # Mark this fee detail as problematic
  def mark_as_problematic
    update(verification_status: VERIFICATION_STATUS_PROBLEMATIC)
  end
  
  # Get the meeting type context for this fee detail
  # This is used to determine which fee types to show in the dropdown
  def meeting_type_context
    # Logic to determine if this is a personal or academic expense
    # This is a simplified example - you would need more sophisticated logic based on your data
    document_name = reimbursement&.document_name.to_s
    
    return "个人" if document_name.include?("个人") || document_name.include?("交通") || document_name.include?("电话")
    return "学术论坛" if document_name.include?("学术") || document_name.include?("会议") || document_name.include?("论坛")
    
    # Check flex_field_7 for additional context (for academic meetings)
    return "学术论坛" if flex_field_7.to_s.include?("学术") || flex_field_7.to_s.include?("会议")
    
    # Default
    "个人"
  end
  
  private
  
  # Update the reimbursement status when the verification status changes
  def update_reimbursement_status
    # Ensure reimbursement exists and is persisted
    if reimbursement&.persisted?
      reimbursement.update_status_based_on_fee_details!
    end
  end
end