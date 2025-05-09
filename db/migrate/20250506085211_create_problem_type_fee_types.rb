class CreateProblemTypeFeeTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :problem_type_fee_types do |t|
      t.references :problem_type, null: false, foreign_key: true
      t.references :fee_type, null: false, foreign_key: true

      t.timestamps
    end
  end
end
