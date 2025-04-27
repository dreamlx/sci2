class CreateFeeDetailSelections < ActiveRecord::Migration[7.1]
  def change
    create_table :fee_detail_selections do |t|
      t.references :fee_detail, foreign_key: true, null: false
      t.references :work_order, polymorphic: true, null: false, index: true
      t.string :verification_status, null: false
      t.text :verification_comment
      t.references :verifier, foreign_key: { to_table: :admin_users }, null: true
      t.datetime :verified_at

      t.timestamps
    end

    # 添加唯一索引确保一个费用明细在一个工单中只被选择一次
    add_index :fee_detail_selections, [:fee_detail_id, :work_order_id, :work_order_type], 
              name: 'index_fee_detail_selections_on_fee_detail_and_work_order',
              unique: true
  end
end
