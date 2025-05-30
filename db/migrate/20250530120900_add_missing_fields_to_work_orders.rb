class AddMissingFieldsToWorkOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :work_orders, :communication_method, :string unless column_exists?(:work_orders, :communication_method)
    add_column :work_orders, :fee_type_id, :integer unless column_exists?(:work_orders, :fee_type_id)
  end
end