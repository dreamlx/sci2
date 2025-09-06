class CleanupOldFeeTypeFields < ActiveRecord::Migration[7.1]
  def up
    # 首先删除相关的索引
    remove_index :fee_types, name: :index_fee_types_on_code if index_exists?(:fee_types, :code)
    remove_index :fee_types, name: :index_fee_types_on_meeting_type if index_exists?(:fee_types, :meeting_type)
    
    # 然后删除旧字段
    remove_column :fee_types, :code if column_exists?(:fee_types, :code)
    remove_column :fee_types, :title if column_exists?(:fee_types, :title)
    remove_column :fee_types, :meeting_type if column_exists?(:fee_types, :meeting_type)
  end

  def down
    # 如果需要回滚，重新添加字段和索引
    add_column :fee_types, :code, :string
    add_column :fee_types, :title, :string
    add_column :fee_types, :meeting_type, :string
    
    add_index :fee_types, :code, unique: true
    add_index :fee_types, :meeting_type
  end
end