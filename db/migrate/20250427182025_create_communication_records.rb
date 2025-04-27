class CreateCommunicationRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :communication_records do |t|
      t.references :communication_work_order, null: false, foreign_key: { to_table: :work_orders }
      t.text :content, null: false
      t.string :communicator_role
      t.string :communicator_name
      t.string :communication_method
      t.datetime :recorded_at, null: false

      t.timestamps
    end
  end
end
