class CommunicationWorkOrder < ApplicationRecord
  # 关联
  belongs_to :reimbursement
  belongs_to :audit_work_order
  has_many :communication_records, dependent: :destroy
  has_many :fee_detail_selections, dependent: :destroy
  has_many :fee_details, through: :fee_detail_selections
  has_many :work_order_status_changes, as: :work_order, dependent: :destroy

  # 引入状态机
  include StateMachines::CommunicationWorkOrderStateMachine

  # 验证
  validates :status, presence: true
  validates :reimbursement_id, presence: true
  validates :audit_work_order_id, presence: true

  # 方法
  def add_communication_record(params)
    communication_records.create(params)
  end

  def notify_parent_work_order
    return unless audit_work_order.present?

    if audit_work_order.status == 'needs_communication'
      audit_work_order.resume_audit
    end
  end

  def select_fee_detail(fee_detail)
    fee_detail_selections.find_or_create_by(fee_detail: fee_detail) do |selection|
      selection.verification_status = 'problematic'
    end
  end

  def resolve_fee_detail_issue(fee_detail, resolution)
    selection = fee_detail_selections.find_by(fee_detail: fee_detail)
    return false unless selection

    # 更新选择记录
    selection.update(
      verification_comment: resolution
    )

    true
  end

  # 获取状态变更历史
  def status_changes
    work_order_status_changes.order(changed_at: :desc)
  end

  private

  # 记录状态变更 - 由状态机模块处理，此方法保留用于直接更新状态的情况
  def record_status_change
    if saved_change_to_status?
      old_status, new_status = saved_change_to_status
      work_order_status_changes.create(
        work_order_type: 'communication',
        from_status: old_status,
        to_status: new_status,
        changed_at: Time.current,
        changed_by: Current.admin_user&.id
      )
    end
  end

  # ActiveAdmin配置
  def self.ransackable_attributes(auth_object = nil)
    %w[id reimbursement_id audit_work_order_id status communication_method initiator_role resolution_summary created_by created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[reimbursement audit_work_order communication_records fee_detail_selections fee_details work_order_status_changes]
  end
end