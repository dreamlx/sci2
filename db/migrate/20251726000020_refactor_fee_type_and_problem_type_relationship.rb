class RefactorFeeTypeAndProblemTypeRelationship < ActiveRecord::Migration[7.1]
  def change
    # Step 1: Rename `code` to `issue_code` for clarity and consistency with the CSV source.
    rename_column :problem_types, :code, :issue_code

    # Step 2: Add the new `fee_type_id` reference.
    # We are keeping it `null: true` for now so we can populate it for existing records.
    add_reference :problem_types, :fee_type, null: true, foreign_key: true
  end
end
