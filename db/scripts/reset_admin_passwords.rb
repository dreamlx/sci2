# Reset Admin User Passwords
# Run with: rails runner "load 'db/scripts/reset_admin_passwords.rb'"

puts 'Resetting admin user passwords...'

# The new password hash for '0987654321'
new_password_hash = '$2a$12$j9k3NwjIe/mZiwh4Cnhyae7eC4OruznsN9m4Nu4KEZ71ytqRwnvAK'

# Get all admin users
admin_users = AdminUser.all
total_count = admin_users.count
updated_count = 0

admin_users.each do |user|
  # Update the encrypted password directly
  user.update_column(:encrypted_password, new_password_hash)
  puts "Reset password for: #{user.email} (#{user.name})"
  updated_count += 1
end

puts "\nPassword reset completed:"
puts "- Updated: #{updated_count} users"
puts "- Total admin users in system: #{total_count}"
puts '- All passwords have been reset to: 0987654321'
