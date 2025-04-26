class CreateOperationHistories < ActiveRecord::Migration[7.1]
  def change
    create_table :operation_histories do |t|
      t.string :document_number, null: false
      t.string :operation_type
      t.datetime :operation_time
      t.string :operator
      t.text :notes
      
      t.timestamps
    end
    
    add_index :operation_histories, :document_number
    add_index :operation_histories, :operation_time
  end
end
