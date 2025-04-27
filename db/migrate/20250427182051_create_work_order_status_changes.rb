class CreateWorkOrderStatusChanges < ActiveRecord::Migration[7.1]
  def change
    create_table :work_order_status_changes do |t|
      t.references :work_order, polymorphic: true, null: false, index: true
      t.string :from_status
      t.string :to_status, null: false
      t.datetime :changed_at, null: false
      t.references :changer, foreign_key: { to_table: :admin_users }, null: true

      t.timestamps
    end
  end
end
