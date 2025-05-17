class AddDocumentCategoryToProblemTypes < ActiveRecord::Migration[7.1]
  def change
    add_reference :problem_types, :document_category, foreign_key: true
    add_column :problem_types, :active, :boolean, null: false, default: true
  end
end
