class AuditWorkOrder < ApplicationRecord
  # 关联
  belongs_to :reimbursement
  belongs_to :express_receipt_work_order, optional: true
  has_many :communication_work_orders, dependent: :nullify
  has_many :fee_detail_selections, dependent: :destroy
  has_many :fee_details, through: :fee_detail_selections
  has_many :work_order_status_changes, as: :work_order, dependent: :destroy

  # 引入状态机
  include StateMachines::AuditWorkOrderStateMachine

  # 验证
  validates :status, presence: true
  validates :audit_result, presence: true, if: -> { %w[approved rejected].include?(status) }
  validates :reimbursement_id, presence: true

  # 方法
  def create_communication_work_order(params = {})
    comm_order = CommunicationWorkOrder.new(
      reimbursement: reimbursement,
      audit_work_order: self,
      status: 'open',
      created_by: created_by,
      **params.except(:fee_detail_ids, :content)
    )

    if comm_order.save
      # 如果指定了费用明细ID，则关联这些费用明细
      if params[:fee_detail_ids].present?
        params[:fee_detail_ids].each do |id|
          fee_detail = FeeDetail.find_by(id: id)
          if fee_detail
            # 创建费用明细选择记录
            comm_order.fee_detail_selections.create(
              fee_detail: fee_detail,
              verification_status: 'problematic'
            )

            # 更新费用明细状态
            fee_detail.update(verification_status: 'problematic')
          end
        end
      end

      # 更新自身状态
      need_communication unless status == 'needs_communication'
    end

    comm_order
  end

  def verify_fee_detail(fee_detail, result = 'verified', comment = nil)
    selection = fee_detail_selections.find_by(fee_detail: fee_detail)
    return false unless selection

    selection.update(
      verification_status: result,
      verification_comment: comment,
      verified_by: Current.admin_user&.id,
      verified_at: Time.current
    )

    # 同时更新费用明细的状态
    case result
    when 'verified'
      fee_detail.update(verification_status: 'verified')
    when 'rejected'
      fee_detail.update(verification_status: 'rejected')
    when 'problematic'
      fee_detail.update(verification_status: 'problematic')
    end

    true
  end

  def select_fee_detail(fee_detail)
    fee_detail_selections.find_or_create_by(fee_detail: fee_detail) do |selection|
      selection.verification_status = 'pending'
    end
  end

  def select_fee_details(fee_detail_ids)
    fee_detail_ids.each do |id|
      fee_detail = FeeDetail.find_by(id: id)
      select_fee_detail(fee_detail) if fee_detail
    end
  end

  # 获取状态变更历史
  def status_changes
    work_order_status_changes.order(changed_at: :desc)
  end

  # 获取未解决的沟通工单
  def pending_communication_work_orders
    communication_work_orders.where.not(status: ['resolved', 'unresolved', 'closed'])
  end

  # 检查是否所有费用明细都已验证
  def all_fees_verified?
    fee_detail_selections.where.not(verification_status: ['verified', 'rejected']).count.zero?
  end

  private

  # 记录状态变更 - 由状态机模块处理，此方法保留用于直接更新状态的情况
  def record_status_change
    if saved_change_to_status?
      old_status, new_status = saved_change_to_status
      work_order_status_changes.create(
        work_order_type: 'audit',
        from_status: old_status,
        to_status: new_status,
        changed_at: Time.current,
        changed_by: Current.admin_user&.id
      )
    end
  end

  # ActiveAdmin配置
  def self.ransackable_attributes(auth_object = nil)
    %w[id reimbursement_id express_receipt_work_order_id status audit_result audit_comment audit_date vat_verified created_by created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[reimbursement express_receipt_work_order communication_work_orders fee_detail_selections fee_details work_order_status_changes]
  end
end