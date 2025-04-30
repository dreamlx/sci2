class AddNeedsCommunicationToWorkOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :work_orders, :needs_communication, :boolean, default: false
  end
end
