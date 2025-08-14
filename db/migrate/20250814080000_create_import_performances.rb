class CreateImportPerformances < ActiveRecord::Migration[7.0]
  def change
    create_table :import_performances do |t|
      t.string :operation_type, null: false
      t.float :elapsed_time, null: false
      t.integer :record_count, default: 0
      t.string :optimization_level
      t.text :optimization_settings
      t.text :notes
      t.timestamps
    end
    
    add_index :import_performances, :operation_type
    add_index :import_performances, :created_at
    add_index :import_performances, :optimization_level
  end
end