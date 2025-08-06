namespace :admin do
  desc "Add default admin user (admin@example.com) if it doesn't exist"
  task add_default_user: :environment do
    email = 'admin@example.com'
    password = 'password'
    
    if AdminUser.exists?(email: email)
      puts "Admin user with email #{email} already exists. Skipping creation."
    else
      begin
        admin_user = AdminUser.create!(
          email: email,
          password: password,
          password_confirmation: password
        )
        puts "Successfully created admin user: #{admin_user.email}"
        puts "Role: #{admin_user.role}"
      rescue => e
        puts "Error creating admin user: #{e.message}"
      end
    end
  end
end