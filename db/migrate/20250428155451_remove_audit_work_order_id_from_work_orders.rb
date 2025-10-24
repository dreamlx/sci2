class RemoveAuditWorkOrderIdFromWorkOrders < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :work_orders, 'work_orders', column: 'audit_work_order_id'
    remove_column :work_orders, :audit_work_order_id, :integer
  end
end
