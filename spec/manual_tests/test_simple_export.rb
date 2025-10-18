#!/usr/bin/env ruby

# Simple test to check if we can access the audit work orders page
# Run with: rails runner test_simple_export.rb

puts "=== Simple Export Access Test ==="

# Test 1: Check if we can access the regular page
puts "\n1. Testing regular page access..."
begin
  require 'rack/test'
  include Rack::Test::Methods
  
  def app
    Rails.application
  end
  
  # First, let's try to access without login
  puts "Testing without authentication..."
  get "/admin/audit_work_orders"
  puts "Response status without auth: #{last_response.status}"
  
  # Now let's check the actual issue
  puts "\n2. Checking specific permissions..."
  admin_user = AdminUser.find_by(email: "admin@example.com")
  ability = Ability.new(admin_user)
  
  puts "User role: #{admin_user.role}"
  puts "Can read AuditWorkOrder: #{ability.can?(:read, AuditWorkOrder)}"
  puts "Can export AuditWorkOrder: #{ability.can?(:export, AuditWorkOrder)}"
  puts "Can manage AuditWorkOrder: #{ability.can?(:manage, AuditWorkOrder)}"
  
  # Test 3: Check if there are any specific controller restrictions
  puts "\n3. Checking controller restrictions..."
  
  # Let's check the controller class directly
  controller_class = Admin::AuditWorkOrdersController
  puts "Controller class: #{controller_class}"
  
  # Check if there are any before_action filters that might be causing issues
  if controller_class.respond_to?(:_process_action_callbacks)
    filters = controller_class._process_action_callbacks
    puts "Before action filters:"
    filters.each do |filter|
      puts "  - #{filter.filter} (#{filter.kind})"
    end
  end
  
  # Test 4: Check if we can access via a different approach
  puts "\n4. Testing alternative access..."
  
  # Try accessing the base admin path
  get "/admin"
  puts "Admin root access status: #{last_response.status}"
  
  # Try accessing a simpler resource
  get "/admin/reimbursements"
  puts "Reimbursements access status: #{last_response.status}"
  
rescue => e
  puts "ERROR during test: #{e.message}"
  puts e.backtrace.first(3)
end

puts "\n=== Test Complete ==="
