class AddStatusToAuditWorkOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :audit_work_orders, :status, :string, default: 'pending', null: false
  end
end
