# frozen_string_literal: true

class AddStatusAndDeletedAtToAdminUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :admin_users, :status, :string, default: 'active', null: false
    add_column :admin_users, :deleted_at, :datetime

    add_index :admin_users, :status
    add_index :admin_users, :deleted_at

    # 为现有用户设置默认状态
    AdminUser.where(status: nil).update_all(status: 'active')
  end
end
