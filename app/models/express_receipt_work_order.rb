class ExpressReceiptWorkOrder < ApplicationRecord
  # 关联
  belongs_to :reimbursement
  has_one :audit_work_order
  has_many :work_order_status_changes, as: :work_order, dependent: :destroy
  
  # 验证
  validates :status, presence: true, inclusion: { in: %w[received processed completed] }
  validates :tracking_number, presence: true
  
  # 回调
  after_save :record_status_change, if: :saved_change_to_status?
  
  # 状态机
  state_machine :status, initial: :received do
    event :process do
      transition :received => :processed
    end
    
    event :complete do
      transition :processed => :completed
      after => :create_audit_work_order
    end
  end
  
  # 方法
  def create_audit_work_order
    AuditWorkOrder.create!(
      reimbursement: reimbursement,
      express_receipt_work_order: self,
      status: 'pending',
      created_by: created_by
    )
  end
  
  private
  
  def record_status_change
    if saved_change_to_status?
      old_status, new_status = saved_change_to_status
      work_order_status_changes.create(
        work_order_type: 'express_receipt',
        from_status: old_status,
        to_status: new_status,
        changed_at: Time.current,
        changed_by: Current.admin_user&.id
      )
    end
  end
  
  # ActiveAdmin配置
  def self.ransackable_attributes(auth_object = nil)
    %w[id reimbursement_id status tracking_number received_at courier_name created_by created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[reimbursement audit_work_order work_order_status_changes]
  end
end