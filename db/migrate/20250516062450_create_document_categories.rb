class CreateDocumentCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :document_categories do |t|
      t.string :name, null: false
      t.text :keywords, null: false, default: ''
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :document_categories, :name, unique: true
  end
end
