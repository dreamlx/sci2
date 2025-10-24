#!/usr/bin/env ruby

# Direct test of Excel export functionality
# Run with: rails runner test_excel_export_direct.rb

puts '=== Direct Excel Export Test ==='

# Test actual HTTP request simulation
begin
  require 'rack/test'
  include Rack::Test::Methods

  def app
    Rails.application
  end

  # Login as admin user
  admin_user = AdminUser.find_by(email: 'admin@example.com')
  if admin_user.nil?
    puts 'ERROR: Admin user not found'
    exit 1
  end

  puts "Testing with admin user: #{admin_user.email}, role: #{admin_user.role}"

  # Create a session
  post '/admin/login', params: { admin_user: { email: 'admin@example.com', password: 'password' } }

  # Test direct access to Excel export
  puts "\nTesting direct Excel export access..."
  get '/admin/audit_work_orders.xlsx'

  puts "Response status: #{last_response.status}"
  puts "Response content type: #{last_response.content_type}"
  puts "Response headers: #{last_response.headers.keys.join(', ')}"

  if last_response.status == 200
    puts '✅ Excel export successful!'
    puts "Response body size: #{last_response.body.bytesize} bytes"

    # Check if it's actually Excel data
    if last_response.body.start_with?("\x50\x4B\x03\x04") # Excel file magic number
      puts '✅ Response appears to be valid Excel file'
    else
      puts '⚠️  Response may not be Excel format'
      puts "First 20 bytes: #{last_response.body[0..20].inspect}"
    end
  elsif last_response.status == 403
    puts '❌ Permission denied - checking authorization'

    # Test if user can access the regular page
    get '/admin/audit_work_orders'
    puts "Regular page access status: #{last_response.status}"

    if last_response.status == 200
      puts '✅ User can access regular page but not Excel export'
    else
      puts '❌ User cannot even access regular page'
    end
  else
    puts "❌ Unexpected response status: #{last_response.status}"
    puts "Response body: #{last_response.body[0..200]}..."
  end
rescue StandardError => e
  puts "ERROR during test: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n=== Test Complete ==="
