class RemoveRemarkFromWorkOrders < ActiveRecord::Migration[7.1]
  def change
    remove_column :work_orders, :remark, :text
  end
end
