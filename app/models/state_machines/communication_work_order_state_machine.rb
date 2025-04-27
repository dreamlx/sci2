module StateMachines
  module CommunicationWorkOrderStateMachine
    extend ActiveSupport::Concern

    included do
      state_machine :status, initial: :open do
        # 定义状态
        state :open, :in_progress, :resolved, :unresolved, :closed

        # 定义事件
        event :start_communication do
          transition open: :in_progress
        end

        event :resolve do
          transition in_progress: :resolved
        end

        event :mark_unresolved do
          transition in_progress: :unresolved
        end

        event :close do
          transition [:resolved, :unresolved] => :closed
        end

        # 状态转换前的回调
        before_transition any => any do |work_order, transition|
          # 可以在这里添加额外的验证逻辑
        end

        # 状态转换后的回调，记录状态变更
        after_transition any => any do |work_order, transition|
          case transition.to
          when :resolved
            work_order.notify_parent_work_order('resolved')
          when :unresolved
            work_order.notify_parent_work_order('unresolved')
          end

          WorkOrderStatusChange.create!(
            work_order_type: 'communication',
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