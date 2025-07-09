class AddNameAndTelephoneToAdminUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :admin_users, :name, :string
    add_column :admin_users, :telephone, :string
  end
end