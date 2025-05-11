class AddInitiatorRoleToCommunicationWorkOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :work_orders, :initiator_role, :string, default: 'internal'
  end
end
