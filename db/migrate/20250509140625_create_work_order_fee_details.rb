# db/migrate/YYYYMMDDHHMMSS_create_work_order_fee_details.rb
class CreateWorkOrderFeeDetails < ActiveRecord::Migration[7.1]
  def change
    create_table :work_order_fee_details do |t|
      t.references :fee_detail, null: false, foreign_key: true
      # references :work_order, polymorphic: true, null: false # 更简洁的写法
      t.integer :work_order_id, null: false
      t.string :work_order_type, null: false

      t.timestamps # 可选，但推荐

      # 复合唯一索引，防止重复关联
      t.index %i[fee_detail_id work_order_id work_order_type], unique: true,
                                                               name: 'index_work_order_fee_details_uniqueness'
      # 为多态关联添加索引 (polymorphic: true 选项会自动创建这个)
      t.index %i[work_order_id work_order_type], name: 'index_work_order_fee_details_on_work_order'
    end
  end
end
