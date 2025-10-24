class RefactorProblemTypesV3 < ActiveRecord::Migration[7.1]
  def change
    # Step 1: Add new context columns to the problem_types table
    add_column :problem_types, :reimbursement_type_code, :string
    add_column :problem_types, :meeting_type_code, :string
    add_column :problem_types, :expense_type_code, :string
    add_column :problem_types, :legacy_problem_code, :string

    # Step 2: Remove the now-obsolete foreign key
    # We're wraping this in a safety check in case the column doesn't exist.
    if column_exists?(:problem_types, :fee_type_id)
      remove_foreign_key :problem_types, :fee_types, if_exists: true
      remove_column :problem_types, :fee_type_id, :integer, if_exists: true
    end

    # Step 3: Add a new unique index to ensure data integrity based on the new context
    # The original `code` column will now store the `issue_code`.
    add_index :problem_types,
              %i[reimbursement_type_code meeting_type_code expense_type_code code],
              unique: true,
              name: 'index_problem_types_on_context_and_code'
  end
end
