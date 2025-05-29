class WorkOrder < ApplicationRecord
  # STI setup
  self.inheritance_column = :type
  
  # Associations
  belongs_to :reimbursement
  belongs_to :creator, class_name: 'AdminUser', foreign_key: 'created_by', optional: true
  belongs_to :problem_type, optional: true
  has_many :work_order_status_changes, as: :work_order, dependent: :destroy
  has_many :work_order_fee_details, dependent: :destroy
  has_many :fee_details, through: :work_order_fee_details
  
  # Validations
  validates :status, presence: true
  validates :reimbursement_id, presence: true
  
  # Constants
  STATUS_PENDING = 'pending'.freeze
  STATUS_APPROVED = 'approved'.freeze
  STATUS_REJECTED = 'rejected'.freeze
  STATUS_COMPLETED = 'completed'.freeze
  
  # State Machine
  state_machine :status, initial: :pending do
    event :approve do
      transition [:pending, :rejected] => :approved
    end
    
    event :reject do
      transition [:pending, :approved] => :rejected
    end
    
    event :complete do
      transition [:pending, :approved, :rejected] => :completed
    end
    
    event :reopen do
      transition :completed => :pending
    end
  end
  
  # Callbacks
  after_create :update_reimbursement_status
  after_save :sync_fee_details_verification_status, if: -> { saved_change_to_status? }
  after_save :record_status_change, if: -> { saved_change_to_status? }
  
  # Scopes
  scope :by_type, ->(type) { where(type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_reimbursement, ->(reimbursement_id) { where(reimbursement_id: reimbursement_id) }
  
  # Class methods
  def self.types
    %w[AuditWorkOrder CommunicationWorkOrder ExpressReceiptWorkOrder]
  end
  
  def self.ransackable_attributes(auth_object = nil)
    %w[id reimbursement_id type status created_by remark processing_opinion tracking_number 
       received_at courier_name audit_result audit_comment audit_date vat_verified 
       created_at updated_at problem_type_id initiator_role]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[reimbursement creator problem_type work_order_status_changes work_order_fee_details fee_details]
  end
  
  # Instance methods
  
  # Add a problem to this work order
  def add_problem(problem_type_id)
    WorkOrderProblemService.new(self).add_problem(problem_type_id)
  end
  
  # Clear all problems from this work order
  def clear_problems
    WorkOrderProblemService.new(self).clear_problems
  end
  
  # Get all problems from this work order
  def get_problems
    WorkOrderProblemService.new(self).get_problems
  end
  
  # Check if the work order can be modified based on reimbursement status
  def can_be_modified?
    !reimbursement.closed?
  end
  
  private
  
  # Update the reimbursement status when a work order is created
  def update_reimbursement_status
    # If reimbursement is in pending status, move it to processing
    if reimbursement.status == 'pending'
      reimbursement.update(status: 'processing')
    end
  end
  
  # Sync fee details verification status based on this work order's status
  def sync_fee_details_verification_status
    # Use the FeeDetailStatusService to update the status of related fee details
    FeeDetailStatusService.new.update_status_for_work_order(self)
  end
  
  # Record status change in work_order_status_changes table
  def record_status_change
    previous_status = status_before_last_save
    current_status = status
    
    # Skip if status didn't actually change
    return if previous_status == current_status
    
    work_order_status_changes.create!(
      from_status: previous_status,
      to_status: current_status,
      changed_at: Time.current,
      changer_id: updated_by_id || created_by
    )
  end
  
  # This is a placeholder for tracking who updated the record
  # In a real implementation, you would set this in the controller
  def updated_by_id
    @updated_by_id
  end
  
  def updated_by=(admin_user)
    @updated_by_id = admin_user&.id
  end
end