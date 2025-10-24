class DropAndCreateWorkOrderFeeDetails < ActiveRecord::Migration[6.1]
  def up
    # 删除旧表
    drop_table :work_order_fee_details if table_exists?(:work_order_fee_details)

    # 创建新表
    create_table :work_order_fee_details do |t|
      t.references :work_order, null: false, foreign_key: true
      t.references :fee_detail, null: false, foreign_key: true

      # 添加唯一索引确保不会有重复关联
      t.index %i[work_order_id fee_detail_id], unique: true, name: 'index_work_order_fee_details_on_wo_and_fd'

      t.timestamps
    end
  end

  def down
    drop_table :work_order_fee_details if table_exists?(:work_order_fee_details)
  end
end
