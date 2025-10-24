namespace :data do
  desc 'Migrate users from old system to admin_users'
  task migrate_users: :environment do
    puts 'Starting user migration from old system...'

    # First run the migration to add fields if not already done
    begin
      ActiveRecord::Migration.check_pending!
    rescue ActiveRecord::PendingMigrationError
      puts 'Running pending migrations first...'
      Rake::Task['db:migrate'].invoke
    end

    # Load and run the seed file
    load Rails.root.join('db', 'seeds', 'admin_users_seed.rb')

    puts "\nUser migration completed successfully!"
  end

  desc 'Verify migrated users'
  task verify_users: :environment do
    puts 'Verifying migrated admin users...'

    expected_emails = [
      'alex.lu@think-bridge.com',
      'jojo.sun@think-bridge.com',
      'steve.zhou@think-bridge.com',
      'cheng.qian@think-bridge.com',
      'ken.wang@think-bridge.com',
      'zedong.wu@think-bridge.com',
      'ada.qiu@think-bridge.com',
      'dora.yang@think-bridge.com',
      'amy.wu@think-bridge.com',
      'lily.dai@think-bridge.com',
      'jack.wang@think-bridge.com',
      'dshen.gu@think-bridge.com',
      'bob.wang@think-bridge.com',
      'amos.lin@think-bridge.com'
    ]

    puts "Expected users: #{expected_emails.count}"
    puts "Total admin users: #{AdminUser.count}"

    missing_users = expected_emails - AdminUser.pluck(:email)
    if missing_users.empty?
      puts '✅ All expected users are present'
    else
      puts "❌ Missing users: #{missing_users.join(', ')}"
    end

    # Check roles
    admin_count = AdminUser.where(role: 'admin').count
    puts "Users with admin role: #{admin_count}"

    # Show sample user
    sample_user = AdminUser.first
    if sample_user
      puts "\nSample user:"
      puts "  Email: #{sample_user.email}"
      puts "  Name: #{sample_user.name}"
      puts "  Role: #{sample_user.role}"
      puts "  Telephone: #{sample_user.telephone}"
      puts "  Created: #{sample_user.created_at}"
    end
  end
end
