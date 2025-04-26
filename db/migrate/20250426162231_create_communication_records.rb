class CreateCommunicationRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :communication_records do |t|
      t.references :communication_work_order, foreign_key: true
      t.text :content
      t.string :communicator_role
      t.string :communicator_name
      t.string :communication_method
      t.datetime :recorded_at
      
      t.timestamps
    end
    
    add_index :communication_records, :recorded_at
  end
end
