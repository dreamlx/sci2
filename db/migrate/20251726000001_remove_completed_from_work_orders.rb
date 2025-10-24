class RemoveCompletedFromWorkOrders < ActiveRecord::Migration[7.1]
  def change
    remove_column :work_orders, :completed, :boolean, default: false, null: false
  end
end
