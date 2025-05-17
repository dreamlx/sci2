class AddActiveToProblemDescriptions < ActiveRecord::Migration[7.1]
  def change
    add_column :problem_descriptions, :active, :boolean, null: false, default: true
  end
end
