class Reimbursement < ApplicationRecord
  # Constants
  STATUS_PENDING = 'pending'.freeze
  STATUS_PROCESSING = 'processing'.freeze
  STATUS_CLOSED = 'closed'.freeze
  
  STATUSES = [
    STATUS_PENDING,
    STATUS_PROCESSING,
    STATUS_CLOSED
  ].freeze
  
  # Associations
  has_many :fee_details, foreign_key: 'document_number', primary_key: 'invoice_number', dependent: :destroy
  has_many :work_orders, dependent: :destroy
  has_many :audit_work_orders, -> { where(type: 'AuditWorkOrder') }, class_name: 'AuditWorkOrder'
  has_many :communication_work_orders, -> { where(type: 'CommunicationWorkOrder') }, class_name: 'CommunicationWorkOrder'
  has_many :express_receipt_work_orders, -> { where(type: 'ExpressReceiptWorkOrder') }, class_name: 'ExpressReceiptWorkOrder'
  has_many :operation_histories, foreign_key: 'document_number', primary_key: 'invoice_number', dependent: :destroy
  
  # Validations
  validates :invoice_number, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :is_electronic, inclusion: { in: [true, false] }
  
  # State Machine
  state_machine :status, initial: :pending do
    event :start_processing do
      transition pending: :processing
    end
    
    event :close_processing do
      transition processing: :closed
    end
    
    event :reopen_to_processing do
      transition closed: :processing
    end
  end
  
  # Scopes
  scope :pending, -> { where(status: STATUS_PENDING) }
  scope :processing, -> { where(status: STATUS_PROCESSING) }
  scope :closed, -> { where(status: STATUS_CLOSED) }
  scope :electronic, -> { where(is_electronic: true) }
  scope :non_electronic, -> { where(is_electronic: false) }
  
  # ActiveAdmin configuration
  def self.ransackable_attributes(auth_object = nil)
    %w[id invoice_number document_name applicant applicant_id company department 
       receipt_status receipt_date submission_date amount is_electronic status 
       external_status approval_date approver_name related_application_number 
       accounting_date document_tags created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[fee_details work_orders audit_work_orders communication_work_orders 
       express_receipt_work_orders operation_histories]
  end
  
  # Instance methods
  
  # Check if this reimbursement is in pending status
  def pending?
    status == STATUS_PENDING
  end
  
  # Check if this reimbursement is in processing status
  def processing?
    status == STATUS_PROCESSING
  end
  
  # Check if this reimbursement is in closed status
  def closed?
    status == STATUS_CLOSED
  end
  
  # Check if this reimbursement is electronic
  def electronic?
    is_electronic
  end
  
  # Check if all fee details are verified
  def all_fee_details_verified?
    fee_details.count > 0 && fee_details.where.not(verification_status: FeeDetail::VERIFICATION_STATUS_VERIFIED).count == 0
  end
  
  # Check if any fee details are problematic
  def any_fee_details_problematic?
    fee_details.problematic.exists?
  end
  
  # Check if this reimbursement can be closed
  def can_be_closed?
    processing? && all_fee_details_verified?
  end
  
  # Close this reimbursement
  def close!
    return false unless can_be_closed?
    update(status: STATUS_CLOSED)
  end
  
  # Check if work orders can be created for this reimbursement
  def can_create_work_orders?
    !closed?
  end
  
  # Get the meeting type context for this reimbursement
  # This is used to determine which fee types to show in the dropdown
  def meeting_type_context
    # Logic to determine if this is a personal or academic expense
    # This is a simplified example - you would need more sophisticated logic based on your data
    return "个人" if document_name.to_s.include?("个人") || document_name.to_s.include?("交通") || document_name.to_s.include?("电话")
    return "学术论坛" if document_name.to_s.include?("学术") || document_name.to_s.include?("会议") || document_name.to_s.include?("论坛")
    
    # Default
    "个人"
  end
end