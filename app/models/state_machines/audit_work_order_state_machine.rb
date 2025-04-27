module StateMachines
  module AuditWorkOrderStateMachine
    extend ActiveSupport::Concern

    included do
      state_machine :status, initial: :pending do
        # 定义状态
        state :pending, :processing, :auditing, :approved, :rejected, :needs_communication, :completed

        # 定义事件
        event :start_processing do
          transition pending: :processing
        end

        event :start_audit do
          transition processing: :auditing
        end

        event :approve do
          transition auditing: :approved
        end

        event :reject do
          transition [:auditing, :needs_communication] => :rejected
        end

        event :need_communication do
          transition auditing: :needs_communication
        end

        event :resume_audit do
          transition needs_communication: :auditing
        end

        event :complete do
          transition [:approved, :rejected] => :completed
        end

        # 状态转换前的回调
        before_transition any => any do |work_order, transition|
          # 可以在这里添加额外的验证逻辑
        end

        # 状态转换后的回调，记录状态变更
        after_transition any => any do |work_order, transition|
          case transition.to
          when :approved
            work_order.update(
              audit_result: 'approved',
              audit_date: Time.current
            )
          when :rejected
            work_order.update(
              audit_result: 'rejected',
              audit_date: Time.current
            )
          end

          WorkOrderStatusChange.create!(
            work_order_type: 'audit',
            work_order_id: work_order.id,
            from_status: transition.from,
            to_status: transition.to,
            changed_at: Time.current,
            changed_by: work_order.created_by || Current.admin_user&.id
          )
          work_order.reload # Refresh associations
        end
      end
    end
  end
end