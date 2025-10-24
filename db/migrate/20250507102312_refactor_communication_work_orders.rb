class RefactorCommunicationWorkOrders < ActiveRecord::Migration[6.0] # 请根据你的 Rails 版本调整 [6.0]
  def up
    # 步骤 1: 添加 audit_comment 列 (如果它尚不存在于 work_orders 表)
    # 我们假设 audit_result 和 audit_date 已经因为 AuditWorkOrder 的存在而存在于 work_orders 表中。
    if column_exists?(:work_orders, :audit_comment)
      say 'Column work_orders.audit_comment already exists.'
    else
      add_column :work_orders, :audit_comment, :text
      say 'Added column work_orders.audit_comment'
    end

    # 步骤 2: 数据迁移 - 将 CommunicationWorkOrder 的 resolution_summary 迁移到 audit_comment
    say_with_time('Migrating data from resolution_summary to audit_comment for CommunicationWorkOrders') do
      # 仅当 resolution_summary 列存在时执行
      if column_exists?(:work_orders, :resolution_summary)
        execute <<-SQL
          UPDATE work_orders
          SET audit_comment = resolution_summary
          WHERE type = 'CommunicationWorkOrder' AND resolution_summary IS NOT NULL AND resolution_summary != '';
        SQL
        # 返回受影响的行数，如果你的数据库驱动支持的话
        # (execute 方法通常不直接返回这个，但 say_with_time 会显示执行时间)
      else
        say 'Column work_orders.resolution_summary does not exist, skipping data migration.'
      end
    end

    # 步骤 3: 移除不再需要的列
    if column_exists?(:work_orders, :resolution_summary)
      remove_column :work_orders, :resolution_summary, :string
      say 'Removed column work_orders.resolution_summary'
    else
      say 'Column work_orders.resolution_summary did not exist, no removal needed.'
    end

    if column_exists?(:work_orders, :needs_communication)
      remove_column :work_orders, :needs_communication, :boolean
      say 'Removed column work_orders.needs_communication'
    else
      say 'Column work_orders.needs_communication did not exist, no removal needed.'
    end

    if column_exists?(:work_orders, :communication_method)
      remove_column :work_orders, :communication_method, :string
      say 'Removed column work_orders.communication_method'
    else
      say 'Column work_orders.communication_method did not exist, no removal needed.'
    end

    if column_exists?(:work_orders, :initiator_role)
      remove_column :work_orders, :initiator_role, :string
      say 'Removed column work_orders.initiator_role'
    else
      say 'Column work_orders.initiator_role did not exist, no removal needed.'
    end
  end

  def down
    say 'Reverting RefactorCommunicationWorkOrders migration...'

    # 反向操作：添加之前移除的列
    add_column :work_orders, :initiator_role, :string unless column_exists?(:work_orders, :initiator_role)
    add_column :work_orders, :communication_method, :string unless column_exists?(:work_orders, :communication_method)
    add_column :work_orders, :needs_communication, :boolean unless column_exists?(:work_orders, :needs_communication)
    add_column :work_orders, :resolution_summary, :string unless column_exists?(:work_orders, :resolution_summary)

    say "Re-added columns: initiator_role, communication_method, needs_communication, resolution_summary (if they didn't exist)."

    # 反向数据迁移：将 audit_comment迁回 resolution_summary
    # 仅当 audit_comment 和 resolution_summary 都存在时执行
    if column_exists?(:work_orders, :audit_comment) && column_exists?(:work_orders, :resolution_summary)
      say_with_time('Migrating data back from audit_comment to resolution_summary for CommunicationWorkOrders') do
        execute <<-SQL
          UPDATE work_orders
          SET resolution_summary = audit_comment
          WHERE type = 'CommunicationWorkOrder' AND audit_comment IS NOT NULL AND audit_comment != '';
        SQL
      end
    else
      say 'Skipping reverse data migration for audit_comment to resolution_summary due to missing column(s).'
    end

    # 关于移除 audit_comment 的说明:
    # 如果 audit_comment 列是专门为此重构添加的，并且 AuditWorkOrder 之前不使用它（或使用了不同的字段如 remark），
    # 那么在回滚时移除 audit_comment 可能是合适的。
    # 但是，如果 AuditWorkOrder 也依赖于 audit_comment 列（并且该列可能在更早的迁移中已存在或为它创建），
    # 则不应在此处移除。
    # 为安全起见，这里不自动移除 audit_comment。请根据项目具体情况手动评估是否需要移除。
    say "IMPORTANT: The 'audit_comment' column was NOT automatically removed during rollback."
    say "Please evaluate if 'audit_comment' should be removed manually based on whether it was solely for this refactor or also used by AuditWorkOrder."
    # 例如，如果确定要移除:
    # if column_exists?(:work_orders, :audit_comment)
    #   # 假设一个检查，判断它是不是被其他模型也使用了
    #   is_audit_comment_only_for_communication_refactor = true # 你需要确定这个逻辑
    #   if is_audit_comment_only_for_communication_refactor
    #     remove_column :work_orders, :audit_comment, :text
    #     say "Removed column work_orders.audit_comment (manual verification was implied)"
    #   end
    # end
  end
end
