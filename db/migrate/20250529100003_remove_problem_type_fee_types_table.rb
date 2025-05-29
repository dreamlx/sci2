class RemoveProblemTypeFeeTypesTable < ActiveRecord::Migration[7.1]
  def up
    # Check if problem_type_fee_types table exists
    if table_exists?(:problem_type_fee_types)
      # Before dropping the table, we should ensure data is migrated
      # This is a placeholder for actual data migration logic
      # In a real implementation, you would add code to migrate data from the join table to the direct association
      
      drop_table :problem_type_fee_types
    end
  end

  def down
    # Only create the table if it doesn't exist
    unless table_exists?(:problem_type_fee_types)
      create_table :problem_type_fee_types do |t|
        t.references :problem_type, null: false, foreign_key: true
        t.references :fee_type, null: false, foreign_key: true

        t.timestamps
      end
    end
  end
end