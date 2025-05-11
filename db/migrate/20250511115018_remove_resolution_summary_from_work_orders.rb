class RemoveResolutionSummaryFromWorkOrders < ActiveRecord::Migration[7.1]
  def change
    remove_column :work_orders, :resolution_summary, :text
  end
end
