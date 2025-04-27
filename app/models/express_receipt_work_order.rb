class ExpressReceiptWorkOrder < ApplicationRecord
  belongs_to :reimbursement
  has_one :audit_work_order
  has_many :work_order_status_changes, as: :work_order, dependent: :destroy

  include StateMachines::ExpressReceiptWorkOrderStateMachine

  validates :status, presence: true, inclusion: { in: %w[received processed completed] }
  validates :tracking_number, presence: true
  validates :courier_name, presence: true
  validates :created_by, presence: true

  def process!
    # Use the state machine event instead of directly updating the status
    process
    save!
  end

  def complete!
    # Use the state machine event instead of directly updating the status
    complete
    save!
  end
  
  def create_audit_work_order
    AuditWorkOrder.create!(
      reimbursement: reimbursement,
      express_receipt_work_order: self,
      status: 'pending',
      created_by: created_by
    )
  end
end