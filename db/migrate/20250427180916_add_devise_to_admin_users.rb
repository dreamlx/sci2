# frozen_string_literal: true

class AddDeviseToAdminUsers < ActiveRecord::Migration[7.1]
  def self.up
    # add_index :admin_users, :email,                unique: true
    # add_index :admin_users, :reset_password_token, unique: true
    # add_index :admin_users, :confirmation_token,   unique: true
    # add_index :admin_users, :unlock_token,         unique: true
  end

  def self.down
    # By default, we don't want to make any assumption about how to roll back a migration when your
    # model already existed. Please edit below which fields you would like to remove in this migration.
    raise ActiveRecord::IrreversibleMigration
  end
end
