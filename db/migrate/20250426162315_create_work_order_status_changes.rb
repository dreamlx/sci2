class CreateWorkOrderStatusChanges < ActiveRecord::Migration[7.1]
  def change
    create_table :work_order_status_changes do |t|
      t.string :work_order_type, null: false
      t.integer :work_order_id, null: false
      t.string :from_status
      t.string :to_status, null: false
      t.datetime :changed_at, null: false
      t.integer :changed_by
      t.string :reason
      
      t.timestamps
    end
    
    add_index :work_order_status_changes, [:work_order_type, :work_order_id]
    add_index :work_order_status_changes, :changed_at
  end
end
