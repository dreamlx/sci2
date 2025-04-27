module StateMachines
  module ExpressReceiptWorkOrderStateMachine
    extend ActiveSupport::Concern

    included do
      state_machine :status, initial: :received do
        event :process do
          transition received: :processed
        end

        event :complete do
          transition processed: :completed
        end

        after_transition any => any do |work_order, transition|
          WorkOrderStatusChange.create!(
            work_order_type: 'express_receipt',
            work_order_id: work_order.id,
            from_status: transition.from,
            to_status: transition.to,
            changed_at: Time.current,
            changed_by: work_order.created_by || Current.admin_user&.id
          )
          work_order.reload # Refresh associations
        end

        after_transition processed: :completed do |work_order|
          AuditWorkOrder.create!(
            reimbursement: work_order.reimbursement,
            express_receipt_work_order: work_order,
            status: 'pending',
            created_by: work_order.created_by
          )
          work_order.reload # Refresh associations
        end
      end
    end
  end
end