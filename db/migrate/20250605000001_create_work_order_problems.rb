class CreateWorkOrderProblems < ActiveRecord::Migration[6.1]
  def change
    create_table :work_order_problems do |t|
      t.references :work_order, null: false, foreign_key: true
      t.references :problem_type, null: false, foreign_key: true
      t.timestamps
    end

    # 添加唯一索引确保不重复添加同一问题
    add_index :work_order_problems, [:work_order_id, :problem_type_id], unique: true, name: 'idx_work_order_problems_unique'
  end
end