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
    approved_wo.validates :audit_comment, presence: { message: "当处理意见为\"可以通过\"时，审核意见不能为空" }
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
    
    # Optional: Event to go back to pending if opinion is cleared (if this business logic is allowed)
    # event :mark_as_pending do
    #   transition [:approved, :rejected] => :pending
    # end

    after_transition do |work_order, transition|
      changer = transition.args.first || Current.admin_user # Assumes changer is the first arg to the event
      work_order.work_order_status_changes.create(
        from_status: transition.from,
        to_status: transition.to,
        changed_at: Time.current,
        changer: changer
      )
      # Set audit_date when moving to approved or rejected
      if transition.to_name.in?([:approved, :rejected]) && work_order.audit_date.nil?
        work_order.audit_date = Time.current
      end
    end
  end

  # Scopes for states
  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  # REMOVED: processing, completed scopes (completed is now a boolean field)

  # Callback to handle status change based on processing_opinion
  # It's recommended that the Service layer explicitly calls state events based on processing_opinion.
  # This callback is commented out to enforce that responsibility on the service layer.
  # before_save :update_status_based_on_processing_opinion, if: :processing_opinion_changed_and_not_completed?

  after_save :handle_fee_detail_selection
  after_create :update_reimbursement_status_to_processing

  def submitted_fee_detail_ids
    @submitted_fee_detail_ids ||= self.fee_details.pluck(:id).map(&:to_s)
  end

  # Method to be called by "Complete Audit" button
  # Note: `completed` is a boolean attribute on the work_orders table
  def mark_as_truly_completed(admin_user) # admin_user passed for potential future use (e.g. logging who completed it)
    return false if self.completed? # Already completed
    if self.status.in?(['approved', 'rejected'])
      # The actual saving of the `completed` flag and any other attributes
      # should ideally be handled by the service layer calling this method,
      # which then calls `update`. This ensures consistency.
      # For now, this method directly updates. If a service calls this, it might just return true/false
      # and the service does the update.
      self.update(completed: true) 
    else
      errors.add(:base, "只有 Approved 或 Rejected 状态的工单才能标记为完成。")
      false
    end
  end

  def editable?
    !self.completed?
  end

  def deletable?
    !self.completed?
  end

  private

  def processing_opinion_changed_and_not_completed?
    processing_opinion_changed? && !self.completed?
  end
  
  def status_changed_to_rejected?
    status_changed? && status == 'rejected'
  end

  def status_changed_to_approved?
    status_changed? && status == 'approved'
  end

  # def update_status_based_on_processing_opinion
  #   # This method is intentionally left commented out.
  #   # Service layer should explicitly call mark_as_approved! or mark_as_rejected!
  #   # based on processing_opinion, passing the current_admin_user.
  #   # If this callback were to be used, it would need a reliable way to get the 'changer'.
  #   # Example if Current.admin_user is reliably set:
  #   # changer = Current.admin_user
  #   # case processing_opinion
  #   # when '可以通过'
  #   #   self.mark_as_approved!(changer) if self.may_mark_as_approved?
  #   # when '无法通过'
  #   #   self.mark_as_rejected!(changer) if self.may_mark_as_rejected?
  #   # when nil, '' # If opinion is cleared and we want to revert to pending
  #   #   # self.mark_as_pending!(changer) if self.may_mark_as_pending? # Add this event if needed
  #   # end
  # end

  def handle_fee_detail_selection
    if defined?(@submitted_fee_detail_ids_from_params) && !@submitted_fee_detail_ids_from_params.nil? 
      current_associated_fee_ids = self.fee_details.pluck(:id).map(&:to_s)
      ids_to_select = @submitted_fee_detail_ids_from_params.map(&:to_s).reject(&:blank?).uniq

      ids_to_add = ids_to_select - current_associated_fee_ids
      ids_to_remove_associations_for = current_associated_fee_ids - ids_to_select

      if ids_to_remove_associations_for.any?
        self.work_order_fee_details.where(fee_detail_id: ids_to_remove_associations_for).destroy_all
      end
      
      ids_to_add.each do |fd_id|
        if FeeDetail.exists?(fd_id)
          self.work_order_fee_details.find_or_create_by(fee_detail_id: fd_id)
        else
          Rails.logger.warn "Attempted to associate non-existent FeeDetail ID: #{fd_id} with WorkOrder ID: #{self.id}, Type: #{self.class.name}"
        end
      end
      @submitted_fee_detail_ids_from_params = nil 
    end
  end

  # Controller needs to assign params[:work_order_type][:submitted_fee_detail_ids] 
  # (e.g. params[:audit_work_order][:submitted_fee_detail_ids])
  # to @submitted_fee_detail_ids_from_params before save.

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

  # 定义问题类型、描述、处理意见的常量 (如果它们是固定的选项)
  # 例如:
  # PROBLEM_TYPES = ["问题类型A", "问题类型B", "其他"].freeze
  # validates :problem_type, inclusion: { in: PROBLEM_TYPES }, allow_blank: true
end