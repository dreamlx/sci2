class CreateProblemDescriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :problem_descriptions do |t|
      t.references :problem_type, null: false, foreign_key: true
      t.string :description

      t.timestamps
    end
  end
end
