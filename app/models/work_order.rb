# app/models/work_order.rb
# frozen_string_literal: true

class WorkOrder < ApplicationRecord
  # STI 基类
  self.table_name = 'work_orders' # 确保表名正确
  
  # 关联
  belongs_to :reimbursement
  belongs_to :creator, class_name: 'AdminUser', foreign_key: 'created_by'
  
  # ADDED: Common associations for problem type and description
  belongs_to :problem_type, optional: true
  belongs_to :problem_description, optional: true
  
  # REVISED Associations: Using polymorphic WorkOrderFeeDetail
  has_many :work_order_fee_details, as: :work_order, dependent: :destroy
  has_many :fee_details, through: :work_order_fee_details
  
  has_many :work_order_status_changes, foreign_key: 'work_order_id', dependent: :destroy

  # 属性 (这些字段应存在于 work_orders 表中)
  # :reimbursement_id
  # :created_by
  # :status
  # :type (用于 STI)
  # :problem_type (string)
  # :problem_description (text)
  # :remark (text)
  # :processing_opinion (text)
  # ... STI 子类特有的字段也在此表中，但值为 null ...

  # 用于表单接收fee_detail_ids
  attr_accessor :fee_detail_ids_attributes # 如果使用 accepts_nested_attributes_for
                                        # 或者 attr_accessor :fee_detail_ids for manual handling
  attr_accessor :submitted_fee_detail_ids  # For the form field

  # 验证
  validates :reimbursement_id, presence: true
  validates :status, presence: true
  # 根据实际需求添加对 problem_type, problem_description 等的验证

  # 根据 processing_opinion 验证相关字段
  with_options if: -> { processing_opinion == '无法通过' && (status == 'rejected' || new_record? || status_changed_to_rejected?) } do |rejected_wo|
    rejected_wo.validates :problem_type_id, presence: { message: "当处理意见为\"无法通过\"时，问题类型不能为空" }
    rejected_wo.validates :problem_description_id, presence: { message: "当处理意见为\"无法通过\"时，问题描述不能为空" }
    rejected_wo.validates :audit_comment, presence: { message: "当处理意见为\"无法通过\"时，审核意见不能为空" }
  end
  with_options if: -> { processing_opinion == '可以通过' && (status == 'approved' || new_record? || status_changed_to_approved?) } do |approved_wo|
    # approved_wo.validates :audit_comment, presence: { message: "当处理意见为\"可以通过\"时，审核意见不能为空" } # <--- 注释掉或删除此行
  end

  # 状态机 (using state_machine gem)
  state_machine :status, initial: :pending do
    state :pending
    state :approved
    state :rejected
    # REMOVED: processing, completed (as a status), problematic, waiting_completion states

    event :mark_as_approved do
      transition [:pending, :rejected] => :approved
    end

    event :mark_as_rejected do
      transition [:pending, :approved] => :rejected
    end
    
    before_transition to: [:approved, :rejected], if: ->(wo) { wo.audit_date.nil? } do |work_order|
      work_order.audit_date = Time.current
    end
    
    after_transition do |work_order, transition|
      event_changer = transition.args.first 
      resolved_changer = event_changer
      if !resolved_changer.is_a?(AdminUser) && Current.admin_user.is_a?(AdminUser)
        # Rails.logger.warn "WorkOrder##{work_order.id} after_transition: Changer from event args was not an AdminUser..." # Keep if still useful
        resolved_changer = Current.admin_user
      elsif !resolved_changer.is_a?(AdminUser)
        # Rails.logger.error "WorkOrder##{work_order.id} after_transition: Changer from event args was not an AdminUser and Current.admin_user is also not valid..." # Keep if still useful
      end

      if resolved_changer.is_a?(AdminUser) || !WorkOrderStatusChange.validators_on(:changer).any? { |v| v.is_a?(ActiveRecord::Validations::PresenceValidator) }
        status_change = work_order.work_order_status_changes.build(
          from_status: transition.from,
          to_status: transition.to,
          changed_at: Time.current,
          changer: resolved_changer, 
          work_order_type: work_order.class.name
        )
        unless status_change.save
          Rails.logger.error "WorkOrder##{work_order.id} after_transition: Failed to save WorkOrderStatusChange. Errors: #{status_change.errors.full_messages.join(', ')}"
        end
      else
        Rails.logger.error "WorkOrder##{work_order.id} after_transition: Skipped creating WorkOrderStatusChange because no valid changer was found."
      end
    end
  end

  # Scopes for states
  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  # REMOVED: processing, completed scopes (completed is now a boolean field)

  # Callback to handle status change based on processing_opinion
  before_save :update_status_based_on_processing_opinion,
              if: -> { will_save_change_to_processing_opinion? && processing_opinion.present? }

  after_save :handle_fee_detail_selection
  after_create :update_reimbursement_status_to_processing

  after_commit :sync_fee_details_verification_status, on: [:create, :update], 
                if: -> { approved? || rejected? } # This condition works

  def submitted_fee_detail_ids
    @submitted_fee_detail_ids ||= self.work_order_fee_details.pluck(:fee_detail_id).map(&:to_s)
  end

  # REMOVED: mark_as_truly_completed method
  # def mark_as_truly_completed(admin_user)
  #   ...
  # end

  # REVISED: editable? and deletable? now depend only on status, or always true if not approved/rejected
  # Or, if approved/rejected are final, they imply not editable/deletable.
  # For now, let's assume if it's approved or rejected, it's no longer editable/deletable in general terms.
  # Specific UI controls might have more nuanced logic.
  def editable?
    !status.in?(['approved', 'rejected'])
  end

  def deletable?
    !status.in?(['approved', 'rejected'])
  end

  private

  # REMOVED the recursive custom method: processing_opinion_changed?
  
  def status_changed_to_rejected?
    status_changed? && status == 'rejected'
  end

  def status_changed_to_approved?
    status_changed? && status == 'approved'
  end

  def update_status_based_on_processing_opinion
    changer_object = Current.admin_user # This should be an AdminUser object
    unless changer_object.is_a?(AdminUser) # More robust check
      Rails.logger.error "WorkOrder##{id}: Current.admin_user is not a valid AdminUser object during update_status_based_on_processing_opinion. Value: #{changer_object.inspect}"
      # Fallback or error handling if changer is critical and not available
      # For WorkOrderStatusChange to be valid, changer usually needs to be present.
      # If we proceed without a valid changer_object, the after_transition callback might fail to create WorkOrderStatusChange.
      # Consider adding an error to the model if this is a critical failure:
      # self.errors.add(:base, "操作用户无效，无法更新状态。")
      # return false # Prevent save if this is a hard requirement
    end
    
    case processing_opinion
    when '可以通过' # Consider using ProcessingOpinionOptions::PASS or a defined constant
      self.mark_as_approved(changer_object) if self.can_mark_as_approved? # Use NON-BANG version
    when '无法通过' # Consider using ProcessingOpinionOptions::FAIL or a defined constant
      self.mark_as_rejected(changer_object) if self.can_mark_as_rejected? # Use NON-BANG version
    end
  end

  def handle_fee_detail_selection
    # Use the value from the accessor `submitted_fee_detail_ids` which is set by the controller
    # Ensure it's not the getter method pre-populating with existing values during a save
    # We need a way to distinguish between form submission and other saves.
    # Let's assume if the accessor has been explicitly set (not nil), it's from a form submission.

    # To avoid confusion with the getter `self.submitted_fee_detail_ids` which loads existing records,
    # let's have the controller set a specific instance variable that this callback checks.
    # The controller should do: resource.instance_variable_set(:@_direct_submitted_fee_ids, params_value)

    if defined?(@_direct_submitted_fee_ids) && !@_direct_submitted_fee_ids.nil? 
      current_associated_fee_ids = self.work_order_fee_details.pluck(:fee_detail_id).map(&:to_s)
      ids_to_select = @_direct_submitted_fee_ids.map(&:to_s).reject(&:blank?).uniq

      ids_to_add = ids_to_select - current_associated_fee_ids
      ids_to_remove_associations_for = current_associated_fee_ids - ids_to_select

      if ids_to_remove_associations_for.any?
        self.work_order_fee_details.where(fee_detail_id: ids_to_remove_associations_for).destroy_all
      end
      
      ids_to_add.each do |fd_id|
        if FeeDetail.exists?(fd_id)
          # Ensure no duplicates are created if somehow find_or_create_by has issues with composite key (though less likely here)
          unless self.work_order_fee_details.exists?(fee_detail_id: fd_id)
            self.work_order_fee_details.create(fee_detail_id: fd_id)
          end
        else
          Rails.logger.warn "Attempted to associate non-existent FeeDetail ID: #{fd_id} with WorkOrder ID: #{self.id}, Type: #{self.class.name}"
        end
      end
      remove_instance_variable(:@_direct_submitted_fee_ids) # Clear after use
    end
  end

  # Controller needs to assign params[:work_order_type][:submitted_fee_detail_ids] 
  # (e.g. params[:audit_work_order][:submitted_fee_detail_ids])
  # to @work_order.instance_variable_set(:@_direct_submitted_fee_ids, ...) before save.

  # ADDED: Method to update reimbursement status after work order creation
  def update_reimbursement_status_to_processing
    if self.reimbursement.present? && self.reimbursement.pending? # Check current state of reimbursement
      begin
        self.reimbursement.start_processing! # Call the event to change reimbursement state
      rescue StateMachines::InvalidTransition => e
        Rails.logger.warn "WorkOrder after_create: Failed to transition reimbursement ID #{self.reimbursement_id} to 'processing'. Current state: #{self.reimbursement.status}. Error: #{e.message}"
      rescue => e
        Rails.logger.error "WorkOrder after_create: Unexpected error while transitioning reimbursement ID #{self.reimbursement_id}. Error: #{e.message}"
      end
    end
  end

  def sync_fee_details_verification_status
    return unless approved? || rejected?

    new_verification_status = approved? ? FeeDetail::VERIFICATION_STATUS_VERIFIED : FeeDetail::VERIFICATION_STATUS_PROBLEMATIC
    associated_fee_detail_ids = self.fee_detail_ids

    if associated_fee_detail_ids.any?
      begin
        updated_count = FeeDetail.where(id: associated_fee_detail_ids).update_all(
          verification_status: new_verification_status,
          updated_at: Time.current
        )
        Rails.logger.info "WorkOrder##{id} sync_fee_details_verification_status: Updated #{updated_count}/#{associated_fee_detail_ids.count} fee details to #{new_verification_status}."
      rescue => e
        Rails.logger.error "WorkOrder##{id} sync_fee_details_verification_status: Error during FeeDetail.update_all: #{e.message}"
      end
    # else # No need to log if there are no details, it's a common case
      # Rails.logger.info "WorkOrder##{id} sync_fee_details_verification_status: No associated fee details to update for status #{self.status}."
    end
  end

  # 定义问题类型、描述、处理意见的常量 (如果它们是固定的选项)
  # 例如:
  # PROBLEM_TYPES = ["问题类型A", "问题类型B", "其他"].freeze
  # validates :problem_type, inclusion: { in: PROBLEM_TYPES }, allow_blank: true
end