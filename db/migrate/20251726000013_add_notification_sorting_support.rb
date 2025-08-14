class AddNotificationSortingSupport < ActiveRecord::Migration[7.0]
  def change
    # 检查列是否存在再添加索引
    if column_exists?(:reimbursements, :has_updates) && column_exists?(:reimbursements, :last_update_at)
      # 添加复合索引以支持高效的通知查询和排序
      add_index :reimbursements, [:has_updates, :last_update_at],
                name: 'index_reimbursements_on_notification_status'
    else
      puts "Columns has_updates or last_update_at do not exist in reimbursements table. Skipping index creation."
    end
    
    # 注意：current_assignee_id字段不存在，暂时跳过这个索引
    # 如果需要用户分配相关的索引，需要先确认字段存在
    # add_index :reimbursements, [:current_assignee_id, :has_updates, :last_update_at], 
    #           name: 'index_reimbursements_on_assignee_and_notifications'
    
    # 确保现有数据的一致性
    reversible do |dir|
      dir.up do
        # 只有当列存在时才初始化通知状态
        if column_exists?(:reimbursements, :has_updates) && column_exists?(:reimbursements, :last_update_at)
          # 为现有数据初始化通知状态
          execute <<-SQL
            UPDATE reimbursements
            SET has_updates = CASE
              WHEN (last_viewed_operation_histories_at IS NULL OR
                    EXISTS (SELECT 1 FROM operation_histories
                           WHERE operation_histories.document_number = reimbursements.invoice_number
                           AND operation_histories.created_at > reimbursements.last_viewed_operation_histories_at))
                OR (last_viewed_express_receipts_at IS NULL OR
                    EXISTS (SELECT 1 FROM work_orders
                           WHERE work_orders.reimbursement_id = reimbursements.id
                           AND work_orders.type = 'ExpressReceiptWorkOrder'
                           AND work_orders.created_at > reimbursements.last_viewed_express_receipts_at))
              THEN true
              ELSE false
            END,
            last_update_at = COALESCE(
              (SELECT MAX(created_at) FROM operation_histories
               WHERE operation_histories.document_number = reimbursements.invoice_number),
              (SELECT MAX(created_at) FROM work_orders
               WHERE work_orders.reimbursement_id = reimbursements.id
               AND work_orders.type = 'ExpressReceiptWorkOrder'),
              reimbursements.updated_at
            )
            WHERE has_updates IS NULL OR last_update_at IS NULL;
          SQL
        else
          puts "Columns has_updates or last_update_at do not exist. Skipping data initialization."
        end
      end
      
      dir.down do
        # 回滚时的清理操作（可选）
        if column_exists?(:reimbursements, :has_updates) && column_exists?(:reimbursements, :last_update_at)
          execute <<-SQL
            UPDATE reimbursements
            SET has_updates = false, last_update_at = NULL
            WHERE has_updates IS NOT NULL;
          SQL
        end
      end
    end
  end
end
