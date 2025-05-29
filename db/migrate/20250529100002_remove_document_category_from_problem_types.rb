class RemoveDocumentCategoryFromProblemTypes < ActiveRecord::Migration[7.1]
  def up
    # Check if problem_types table exists
    if table_exists?(:problem_types)
      # Check if document_category_id column exists
      if column_exists?(:problem_types, :document_category_id)
        # Before removing the column, we should ensure data is migrated
        # This is a placeholder for actual data migration logic
        # In a real implementation, you would add code to migrate data from document_category to fee_type
        
        # Now remove the column and its index
        remove_index :problem_types, :document_category_id if index_exists?(:problem_types, :document_category_id)
        remove_reference :problem_types, :document_category, foreign_key: true
      end
    end
  end

  def down
    # Check if problem_types table exists
    if table_exists?(:problem_types)
      # Add the column back if it doesn't exist
      unless column_exists?(:problem_types, :document_category_id)
        add_reference :problem_types, :document_category, foreign_key: true
      end
    end
    # Note: This doesn't restore the data that was in this column
  end
end