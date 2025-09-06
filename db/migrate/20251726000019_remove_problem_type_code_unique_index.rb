class RemoveProblemTypeCodeUniqueIndex < ActiveRecord::Migration[7.1]
  def up
    # 删除错误的唯一索引，这个索引导致 code 字段必须全局唯一
    # 这与我们的业务逻辑冲突，code 应该在上下文范围内唯一即可
    remove_index :problem_types, name: :index_problem_types_on_code_and_fee_type_id, if_exists: true
  end

  def down
    # 回滚时重新添加索引（如果需要）
    add_index :problem_types, :code, unique: true, name: :index_problem_types_on_code_and_fee_type_id
  end
end
