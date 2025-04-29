class AddMissingIndexes < ActiveRecord::Migration[7.1]
  def change
    # For fee_detail_selections table
    add_index :fee_detail_selections, :verification_status
    
    # For work_order_status_changes table
    add_index :work_order_status_changes, :changed_at
  end
end