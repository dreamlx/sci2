class AddCompletedToWorkOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :work_orders, :completed, :boolean, default: false, null: false
  end
end
