class EnsureExternalFeeIdPresence < ActiveRecord::Migration[6.1]
  def up
    # Check if external_fee_id column exists first
    unless column_exists?(:fee_details, :external_fee_id)
      puts "external_fee_id column does not exist in fee_details table. Skipping migration."
      return
    end
    
    # Get all fee_details with nil external_fee_id
    fee_details_with_nil_id = execute("SELECT id FROM fee_details WHERE external_fee_id IS NULL").to_a
    
    if fee_details_with_nil_id.any?
      puts "Found #{fee_details_with_nil_id.size} fee_details with nil external_fee_id"
      
      # Generate and update external_fee_id for each record
      fee_details_with_nil_id.each do |row|
        id = row['id']
        # Generate a unique ID with a prefix to identify migration-generated IDs
        new_external_id = "MIG-#{SecureRandom.hex(8)}"
        
        execute <<-SQL
          UPDATE fee_details 
          SET external_fee_id = '#{new_external_id}', 
              updated_at = NOW() 
          WHERE id = #{id}
        SQL
        
        puts "  Updated fee_detail ##{id} with external_fee_id: #{new_external_id}"
      end
    else
      puts "No fee_details with nil external_fee_id found"
    end
    
    # Add NOT NULL constraint to external_fee_id only if column exists
    if column_exists?(:fee_details, :external_fee_id)
      change_column_null :fee_details, :external_fee_id, false
      
      # Add a database-level uniqueness constraint
      add_index :fee_details, :external_fee_id, unique: true,
                name: 'index_fee_details_on_external_fee_id_unique',
                if_not_exists: true
    end
  end
  
  def down
    # Remove the NOT NULL constraint
    change_column_null :fee_details, :external_fee_id, true
    
    # Remove the uniqueness constraint if it exists
    remove_index :fee_details, name: 'index_fee_details_on_external_fee_id_unique', if_exists: true
  end
end