class RemoveProblemDescriptionsTable < ActiveRecord::Migration[7.1]
  def up
    # Check if problem_descriptions table exists
    return unless table_exists?(:problem_descriptions)

    # Check if work_orders table exists and has problem_description_id column
    if table_exists?(:work_orders) && column_exists?(:work_orders, :problem_description_id)
      # Before dropping the table, we should ensure data is migrated
      # This is a placeholder for actual data migration logic
      # In a real implementation, you would add code to migrate relevant data to problem_types

      # First remove foreign key references from work_orders
      remove_column :work_orders, :problem_description_id
    end

    # Now drop the table
    drop_table :problem_descriptions
  end

  def down
    # Only create the table if it doesn't exist
    unless table_exists?(:problem_descriptions)
      create_table :problem_descriptions do |t|
        t.references :problem_type, null: false, foreign_key: true
        t.string :description
        t.boolean :active, default: true, null: false

        t.timestamps
      end
    end

    # Add the column back to work_orders if it doesn't exist
    return unless table_exists?(:work_orders) && !column_exists?(:work_orders, :problem_description_id)

    add_column :work_orders, :problem_description_id, :integer
  end
end
