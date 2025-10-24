class RemoveDocumentCategoryFromProblemTypes < ActiveRecord::Migration[7.1]
  def up
    # Check if problem_types table exists
    return unless table_exists?(:problem_types)
    # Check if document_category_id column exists
    return unless column_exists?(:problem_types, :document_category_id)

    # Before removing the column, we should ensure data is migrated
    # This is a placeholder for actual data migration logic
    # In a real implementation, you would add code to migrate data from document_category to fee_type

    # Now remove the foreign key constraint first, then the column and index
    remove_reference :problem_types, :document_category, foreign_key: true
  end

  def down
    # Check if problem_types table exists
    return unless table_exists?(:problem_types)
    # Add the column back if it doesn't exist
    return if column_exists?(:problem_types, :document_category_id)

    add_reference :problem_types, :document_category, foreign_key: true

    # NOTE: This doesn't restore the data that was in this column
  end
end
