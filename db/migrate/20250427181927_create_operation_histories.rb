class CreateOperationHistories < ActiveRecord::Migration[7.1]
  def change
    create_table :operation_histories do |t|
      t.string :document_number, null: false, index: true # 关联到 reimbursements.invoice_number
      t.string :operation_type
      t.datetime :operation_time
      t.string :operator
      t.text :notes
      t.string :form_type
      t.string :operation_node

      t.timestamps
    end

    # 添加复合索引用于操作历史重复检查
    add_index :operation_histories, %i[document_number operation_type operation_time operator],
              name: 'index_operation_histories_on_document_and_operation',
              unique: true
  end
end
