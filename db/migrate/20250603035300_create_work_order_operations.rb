class CreateWorkOrderOperations < ActiveRecord::Migration[7.0]
  def change
    create_table :work_order_operations do |t|
      t.references :work_order, null: false, foreign_key: true
      t.references :admin_user, null: false, foreign_key: true
      t.string :operation_type, null: false # 'create', 'update', 'status_change', 'add_problem', 'remove_problem', etc.
      t.text :details # JSON格式，存储操作的详细信息
      t.text :previous_state # JSON格式，存储操作前的状态
      t.text :current_state # JSON格式，存储操作后的状态
      t.datetime :created_at, null: false
      
      t.index [:work_order_id, :created_at]
      t.index [:admin_user_id, :created_at]
      t.index [:operation_type, :created_at]
    end
  end
end