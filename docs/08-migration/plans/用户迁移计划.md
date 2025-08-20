# User Migration Plan

## Objective
Migrate users from old system (`users` table) to ActiveAdmin (`admin_users` table) with:
- All users assigned 'admin' role
- Preserved password encryption
- Maintained email uniqueness

## Data Mapping

| Old Field (`users`) | New Field (`admin_users`) | Notes |
|---------------------|--------------------------|-------|
| id | (not migrated) | New IDs will be generated |
| email | email | Must remain unique |
| encrypted_password | encrypted_password | Must use same encryption |
| reset_password_token | reset_password_token |  |
| reset_password_sent_at | reset_password_sent_at |  |
| remember_created_at | remember_created_at |  |
| created_at | created_at | Preserve original timestamps |
| updated_at | updated_at |  |
| name | (optional) | Could add to admin_users |
| role | role | Set to 'admin' for all |
| telephone | (optional) | Could add to admin_users |

## Implementation Steps

1. Create migration to add optional fields (if needed):
   ```ruby
   class AddNameAndTelephoneToAdminUsers < ActiveRecord::Migration[7.1]
     def change
       add_column :admin_users, :name, :string
       add_column :admin_users, :telephone, :string
     end
   end
   ```

2. Create UserMigrationService with these methods:
   - `parse_sql_dump`: Extract user data from SQL file
   - `migrate_users`: Transform and save to admin_users
   - `handle_duplicates`: Resolve email conflicts
   - `verify_passwords`: Ensure encryption compatibility

3. Create rake task to run migration:
   ```ruby
   namespace :data do
     desc "Migrate users from old system"
     task migrate_users: :environment do
       UserMigrationService.new.migrate_users
     end
   end
   ```

## Verification Steps

1. Count check: Verify same number of users migrated
2. Sample check: Test login with migrated credentials
3. Role check: Confirm all have 'admin' role
4. Uniqueness check: No duplicate emails

## Rollback Plan

1. Backup database before migration
2. Document original admin_users count
3. Provide script to delete migrated users if needed