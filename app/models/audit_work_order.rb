# app/models/audit_work_order.rb
# frozen_string_literal: true

class AuditWorkOrder < WorkOrder
  # 验证 (REMOVED - Common validations moved to WorkOrder)
  # validates :reimbursement, presence: true (Still needed if not in WorkOrder or for specificity)
  # validates :status, ... (Inherited)
  # validates :resolution, ... (Inherited)
  # validates :audit_date, ... (Inherited)
  
  # Specific validations for AuditWorkOrder
  # validates :problem_type, presence: true, if: -> { resolution == 'rejected' } (OLD)
  # validates :problem_description, presence: true, if: -> { resolution == 'rejected' } (OLD)
  validates :problem_type_id, presence: true, if: -> { resolution == 'rejected' && problem_type_id.blank? }
  validates :problem_description_id, presence: true, if: -> { resolution == 'rejected' && problem_description_id.blank? }
  validates :audit_comment, presence: true, if: -> { resolution == 'rejected' && audit_comment.blank? }
  validates :vat_verified, inclusion: { in: [true, false] }, if: :processing_opinion_pass_or_cannot_pass?

  # ActiveAdmin 支持
  def self.ransackable_attributes(auth_object = nil)
    super + ["vat_verified"]
  end

  def self.ransackable_associations(auth_object = nil)
    super + [] # Add any specific associations for AuditWorkOrder here
  end

  # private (REMOVED - Methods moved to WorkOrder)
  # def ensure_resolution_is_pending_if_nil ... end
  # def set_status_based_on_resolution ... end

  private

  def processing_opinion_pass_or_cannot_pass?
    processing_opinion.in?(['可以通过', '无法通过'])
  end
end