class RemoveDocumentCategoriesTable < ActiveRecord::Migration[7.1]
  def up
    # Check if document_categories table exists
    return unless table_exists?(:document_categories)

    # We should have already removed references to this table from problem_types
    # in the previous migration (20250529100002_remove_document_category_from_problem_types)

    # Now we can safely drop the table
    drop_table :document_categories
  end

  def down
    # Only create the table if it doesn't exist
    return if table_exists?(:document_categories)

    create_table :document_categories do |t|
      t.string :name, null: false
      t.text :keywords, default: '', null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :document_categories, :name, unique: true
  end
end
