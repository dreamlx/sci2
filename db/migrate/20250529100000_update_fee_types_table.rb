class UpdateFeeTypesTable < ActiveRecord::Migration[7.1]
  def change
    # Check if fee_types table exists
    if table_exists?(:fee_types)
      # If it exists, update it
      # Add code column if it doesn't exist
      unless column_exists?(:fee_types, :code)
        add_column :fee_types, :code, :string, null: false, default: ""
      end
      
      # Add title column if it doesn't exist
      unless column_exists?(:fee_types, :title)
        add_column :fee_types, :title, :string, null: false, default: ""
      end
      
      # Add meeting_type column if it doesn't exist
      unless column_exists?(:fee_types, :meeting_type)
        add_column :fee_types, :meeting_type, :string, null: false, default: "个人"
      end
      
      # Add active column if it doesn't exist
      unless column_exists?(:fee_types, :active)
        add_column :fee_types, :active, :boolean, default: true, null: false
      end
      
      # Add unique index for code if it doesn't exist
      unless index_exists?(:fee_types, :code, unique: true)
        add_index :fee_types, :code, unique: true
      end
      
      # Add index for meeting_type for faster queries if it doesn't exist
      unless index_exists?(:fee_types, :meeting_type)
        add_index :fee_types, :meeting_type
      end
      
      # Add index for active status if it doesn't exist
      unless index_exists?(:fee_types, :active)
        add_index :fee_types, :active
      end
    else
      # If it doesn't exist, create it
      create_table :fee_types do |t|
        t.string :name
        t.string :code, null: false
        t.string :title, null: false
        t.string :meeting_type, null: false
        t.boolean :active, default: true, null: false
        
        t.timestamps
      end
      
      # Add indexes
      add_index :fee_types, :code, unique: true
      add_index :fee_types, :meeting_type
      add_index :fee_types, :active
    end
  end
end