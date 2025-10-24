class SimplifyFeeRelatedTables < ActiveRecord::Migration[7.1]
  def up
    puts 'Starting migration to simplify fee-related tables...'

    # 1. Remove fee_detail_selections table
    # This table links fee_details to work_orders and admin_users (verifier)
    if table_exists?(:fee_detail_selections)
      # Remove foreign keys pointing from fee_detail_selections
      if foreign_key_exists?(:fee_detail_selections, :admin_users, column: :verifier_id)
        remove_foreign_key :fee_detail_selections, :admin_users, column: :verifier_id
        puts 'Removed foreign key from fee_detail_selections to admin_users.'
      end
      if foreign_key_exists?(:fee_detail_selections, :fee_details)
        remove_foreign_key :fee_detail_selections, :fee_details
        puts 'Removed foreign key from fee_detail_selections to fee_details.'
      end

      drop_table :fee_detail_selections do |t|
        # Columns from schema for context during drop, no actual action needed here for columns
        # t.integer "fee_detail_id", null: false
        # t.string "work_order_type", null: false
        # t.integer "work_order_id", null: false
        # t.text "verification_comment"
        # t.integer "verifier_id"
        # t.datetime "verified_at"
        # t.datetime "created_at", null: false
        # t.datetime "updated_at", null: false
      end
      puts 'Dropped table fee_detail_selections.'
    else
      puts 'Table fee_detail_selections does not exist, skipping drop.'
    end

    # 2. Remove problem_type_fee_types table
    # This table joins problem_types and fee_types
    if table_exists?(:problem_type_fee_types)
      # Remove foreign keys pointing from problem_type_fee_types
      if foreign_key_exists?(:problem_type_fee_types, :fee_types)
        remove_foreign_key :problem_type_fee_types, :fee_types
        puts 'Removed foreign key from problem_type_fee_types to fee_types.'
      end
      if foreign_key_exists?(:problem_type_fee_types, :problem_types)
        remove_foreign_key :problem_type_fee_types, :problem_types
        puts 'Removed foreign key from problem_type_fee_types to problem_types.'
      end

      drop_table :problem_type_fee_types do |t|
        # Columns from schema for context
        # t.integer "problem_type_id", null: false
        # t.integer "fee_type_id", null: false
        # t.datetime "created_at", null: false
        # t.datetime "updated_at", null: false
      end
      puts 'Dropped table problem_type_fee_types.'
    else
      puts 'Table problem_type_fee_types does not exist, skipping drop.'
    end

    # 3. Remove fee_types table
    if table_exists?(:fee_types)
      drop_table :fee_types do |t|
        # Columns from schema for context
        # t.string "name"
        # t.datetime "created_at", null: false
        # t.datetime "updated_at", null: false
      end
      puts 'Dropped table fee_types.'
    else
      puts 'Table fee_types does not exist, skipping drop.'
    end

    # The fee_details.fee_type (string) column already exists and will be used
    # to store the fee type name directly. No schema changes needed for fee_details itself.
    puts 'Migration completed. The fee_details.fee_type column will store fee type names.'
    puts 'The association between FeeDetail and WorkOrder via fee_detail_selections has been removed.'
  end

  def down
    puts 'Reverting migration to simplify fee-related tables...'

    # 1. Recreate fee_types table
    create_table :fee_types do |t|
      t.string 'name'
      t.timestamps
    end
    puts 'Recreated table fee_types.'

    # 2. Recreate problem_type_fee_types table
    create_table :problem_type_fee_types do |t|
      t.references :problem_type, null: false # foreign_key: true will be added below
      t.references :fee_type, null: false     # foreign_key: true will be added below
      t.timestamps
    end
    add_foreign_key :problem_type_fee_types, :problem_types
    add_foreign_key :problem_type_fee_types, :fee_types
    # Add indexes as they were in the original schema
    add_index :problem_type_fee_types, :fee_type_id, name: 'index_problem_type_fee_types_on_fee_type_id'
    add_index :problem_type_fee_types, :problem_type_id, name: 'index_problem_type_fee_types_on_problem_type_id'
    puts 'Recreated table problem_type_fee_types with foreign keys and indexes.'

    # 3. Recreate fee_detail_selections table
    create_table :fee_detail_selections do |t|
      t.references :fee_detail, null: false # foreign_key: true will be added below
      t.string 'work_order_type', null: false
      t.integer 'work_order_id', null: false # This would reference a polymorphic work_order
      t.text 'verification_comment'
      t.references :verifier, foreign_key: { to_table: :admin_users } # Assuming verifier_id links to admin_users
      t.datetime 'verified_at'
      t.timestamps
    end
    add_foreign_key :fee_detail_selections, :fee_details
    # Add indexes as they were in the original schema
    add_index :fee_detail_selections, %i[fee_detail_id work_order_id work_order_type],
              name: 'index_fee_detail_selections_on_fee_detail_and_work_order', unique: true
    # index for fee_detail_id is covered by references :fee_detail
    # index for verifier_id is covered by references :verifier
    add_index :fee_detail_selections, %i[work_order_type work_order_id],
              name: 'index_fee_detail_selections_on_work_order'
    puts 'Recreated table fee_detail_selections with foreign keys and indexes.'

    # NOTE: Data restoration into fee_types or re-establishing links
    # in problem_type_fee_types and fee_detail_selections is not handled by this rollback.
    # The fee_details.fee_type column would still contain the string values.
    puts 'Rollback completed. Manual data restoration might be needed if data was lost.'
  end
end
