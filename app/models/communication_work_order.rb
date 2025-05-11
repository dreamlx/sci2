# app/models/communication_work_order.rb
# frozen_string_literal: true

class CommunicationWorkOrder < WorkOrder
  # 关联 (REMOVED to align with AuditWorkOrder - assuming AuditWorkOrder does not have these direct associations)
  # belongs_to :problem_type, optional: true
  # belongs_to :problem_description, optional: true
  
  # 验证
  # validates :initiator_role, presence: true, inclusion: { in: %w[internal external] } # REMOVED to align with AuditWorkOrder
  
  # problem_type_id and problem_description_id validations should be identical to AuditWorkOrder's
  # validates :problem_type_id, presence: true, if: -> { resolution == 'rejected' } # REMOVED - Inherited from WorkOrder
  # validates :problem_description_id, presence: true, if: -> { resolution == 'rejected' } # REMOVED - Inherited from WorkOrder
  
  # ActiveAdmin 支持
  def self.subclass_ransackable_attributes
    # To be fully aligned with AuditWorkOrder, if AuditWorkOrder only has 'vat_verified' (which is audit specific),
    # then CommunicationWorkOrder should likely have an empty array here, unless it has its own unique searchable fields
    # that are NOT shared via WorkOrder and NOT present in AuditWorkOrder.
    # Given the goal of complete alignment and no specific CommunicationWorkOrder fields mentioned as analogous to vat_verified,
    # this should be an empty array.
    [] 
  end

  # All other specific methods, scopes, or callbacks previously in CommunicationWorkOrder are removed
  # as they are now inherited from WorkOrder or not part of the aligned design.

  # Validations
  validates :problem_type_id, presence: true, if: -> { resolution == 'rejected' && problem_type_id.blank? }
  validates :problem_description_id, presence: true, if: -> { resolution == 'rejected' && problem_description_id.blank? }
  validates :audit_comment, presence: true, if: -> { resolution == 'rejected' && audit_comment.blank? }

  # Ransack
  def self.ransackable_attributes(auth_object = nil)
    super + [] # Add specific attributes for CommunicationWorkOrder here if any in the future
  end

  def self.ransackable_associations(auth_object = nil)
    super + [] # Add any specific associations for CommunicationWorkOrder here
  end

  # Scopes (if any specific to CommunicationWorkOrder)
  # Example: scope :with_specific_communication_flag, -> { where(specific_flag: true) }
end