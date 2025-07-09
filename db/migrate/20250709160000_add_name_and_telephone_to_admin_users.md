# Migration: Add Name and Telephone to AdminUsers

```ruby
class AddNameAndTelephoneToAdminUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :admin_users, :name, :string
    add_column :admin_users, :telephone, :string
  end
end
```

This migration adds the optional name and telephone fields to match the old system's user table structure.