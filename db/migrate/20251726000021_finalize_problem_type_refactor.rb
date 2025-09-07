class FinalizeProblemTypeRefactor < ActiveRecord::Migration[7.1]
  def change
    # Now that the data migration is complete, we can enforce the NOT NULL constraint.
    change_column_null :problem_types, :fee_type_id, false

    # Before removing the columns, we must drop the old unique index that depends on them.
    remove_index :problem_types, name: "index_problem_types_on_context_and_code"

    # And finally, remove the old redundant columns.
    remove_column :problem_types, :reimbursement_type_code, :string
    remove_column :problem_types, :meeting_type_code, :string
    remove_column :problem_types, :expense_type_code, :string
  end
end
