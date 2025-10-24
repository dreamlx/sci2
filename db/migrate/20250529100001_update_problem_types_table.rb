class UpdateProblemTypesTable < ActiveRecord::Migration[7.1]
  def change
    # Check if problem_types table exists
    if table_exists?(:problem_types)
      # If it exists, update it
      # Add code column if it doesn't exist
      add_column :problem_types, :code, :string, null: false, default: '' unless column_exists?(:problem_types, :code)

      # Add title column if it doesn't exist
      add_column :problem_types, :title, :string, null: false, default: '' unless column_exists?(:problem_types, :title)

      # Add sop_description column if it doesn't exist
      add_column :problem_types, :sop_description, :text unless column_exists?(:problem_types, :sop_description)

      # Add standard_handling column if it doesn't exist
      add_column :problem_types, :standard_handling, :text unless column_exists?(:problem_types, :standard_handling)

      # Add fee_type_id column if it doesn't exist
      add_reference :problem_types, :fee_type, foreign_key: true unless column_exists?(:problem_types, :fee_type_id)

      # Add composite unique index for code within fee_type if it doesn't exist
      unless index_exists?(:problem_types, %i[code fee_type_id], unique: true)
        add_index :problem_types, %i[code fee_type_id], unique: true
      end
    else
      # If it doesn't exist, create it
      create_table :problem_types do |t|
        t.string :name
        t.string :code, null: false
        t.string :title, null: false
        t.text :sop_description
        t.text :standard_handling
        t.references :fee_type, foreign_key: true
        t.boolean :active, default: true, null: false

        t.timestamps
      end

      # Add composite unique index for code within fee_type
      add_index :problem_types, %i[code fee_type_id], unique: true
    end
  end
end
