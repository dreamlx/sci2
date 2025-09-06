class AddContextFieldsToFeeTypes < ActiveRecord::Migration[7.1]
  def change
    add_column :fee_types, :reimbursement_type_code, :string
    add_column :fee_types, :meeting_type_code, :string
    add_column :fee_types, :expense_type_code, :string
    add_column :fee_types, :meeting_name, :string
    
    # Remove the old, redundant meeting_type column
    remove_column :fee_types, :meeting_type, :string, if_exists: true
    # Remove the legacy code column, as it's replaced by expense_type_code
    remove_column :fee_types, :code, :string, if_exists: true

    # Add a unique index to ensure the combination is unique
    add_index :fee_types,
              [:reimbursement_type_code, :meeting_type_code, :expense_type_code],
              unique: true,
              name: 'index_fee_types_on_context'
  end
end
