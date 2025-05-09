class CreateProblemTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :problem_types do |t|
      t.string :name

      t.timestamps
    end
  end
end
