class RemoveMaterialsRelatedTables < ActiveRecord::Migration[7.1]
  def up
    # Check if work_orders table exists and has material_ids column
    if table_exists?(:work_orders) && column_exists?(:work_orders, :material_ids)
      # First remove material_ids from work_orders
      remove_column :work_orders, :material_ids
    end
    
    # Check if problem_type_materials table exists
    if table_exists?(:problem_type_materials)
      # Now drop the join table first (to maintain referential integrity)
      drop_table :problem_type_materials
    end
    
    # Check if materials table exists
    if table_exists?(:materials)
      # Then drop the materials table
      drop_table :materials
    end
  end

  def down
    # Only create the materials table if it doesn't exist
    unless table_exists?(:materials)
      # Recreate materials table
      create_table :materials do |t|
        t.string :name

        t.timestamps
      end
    end
    
    # Only create the problem_type_materials table if it doesn't exist
    unless table_exists?(:problem_type_materials)
      # Recreate problem_type_materials join table
      create_table :problem_type_materials do |t|
        t.references :problem_type, null: false, foreign_key: true
        t.references :material, null: false, foreign_key: true

        t.timestamps
      end
    end
    
    # Add material_ids back to work_orders if it doesn't exist
    if table_exists?(:work_orders) && !column_exists?(:work_orders, :material_ids)
      add_column :work_orders, :material_ids, :text
    end
  end
end