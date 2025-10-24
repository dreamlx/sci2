class AddFillingIdToWorkOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :work_orders, :filling_id, :string, limit: 10
    add_index :work_orders, :filling_id, unique: true,
                                         where: "type = 'ExpressReceiptWorkOrder' AND filling_id IS NOT NULL"
  end
end
