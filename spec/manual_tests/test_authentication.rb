#!/usr/bin/env ruby

# Test authentication and login
# Run with: rails runner test_authentication.rb

puts '=== Authentication Test ==='

# Test 1: Check if admin user exists and can login
puts "\n1. Checking admin user..."
admin_user = AdminUser.find_by(email: 'admin@example.com')
if admin_user
  puts "Found admin user: #{admin_user.email}"
  puts "Role: #{admin_user.role}"
  puts "Encrypted password: #{admin_user.encrypted_password.present? ? 'Present' : 'Missing'}"
else
  puts 'ERROR: Admin user not found!'
  exit 1
end

# Test 2: Check Devise authentication
puts "\n2. Testing Devise authentication..."
begin
  # Try to authenticate with Devise
  authenticated = admin_user.valid_password?('password')
  puts "Password validation: #{authenticated ? 'SUCCESS' : 'FAILED'}"

  # Check if user is active
  puts "User active: #{admin_user.active_for_authentication?}"
  puts "User confirmed: #{admin_user.confirmed?}"
rescue StandardError => e
  puts "ERROR in authentication test: #{e.message}"
end

# Test 3: Check warden authentication
puts "\n3. Testing warden authentication..."
begin
  # Create a mock request environment
  env = {
    'warden' => Warden::Proxy.new({}, Warden::Manager.new({})),
    'REQUEST_METHOD' => 'GET',
    'PATH_INFO' => '/admin/audit_work_orders'
  }

  warden = env['warden']
  puts "Warden proxy created: #{warden.class}"

  # Try to authenticate with warden
  warden.set_user(admin_user, scope: :admin_user)
  puts "User set in warden: #{warden.user(:admin_user).present?}"
rescue StandardError => e
  puts "ERROR in warden test: #{e.message}"
end

# Test 4: Check if we can simulate a login
puts "\n4. Testing login simulation..."
begin
  # Check routes
  puts "Login route exists: #{Rails.application.routes.routes.any? { |r| r.path.spec.to_s.include?('admin/login') }}"

  # Check if we can access login page
  require 'rack/test'
  include Rack::Test::Methods

  def app
    Rails.application
  end

  get '/admin/login'
  puts "Login page access status: #{last_response.status}"
rescue StandardError => e
  puts "ERROR in login test: #{e.message}"
end

puts "\n=== Test Complete ==="
