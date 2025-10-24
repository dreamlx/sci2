#!/usr/bin/env ruby

# Test script for ActiveAdmin export functionality
# Run with: rails runner test_export_functionality.rb

puts '=== ActiveAdmin Export Functionality Test ==='

# Test 1: Check permissions
puts "\n1. Testing permissions..."
admin_user = AdminUser.find_by(email: 'admin@example.com')
if admin_user
  puts "Found admin user: #{admin_user.email}, role: #{admin_user.role}"

  ability = Ability.new(admin_user)
  puts "Can export AuditWorkOrder: #{ability.can?(:export, AuditWorkOrder)}"
  puts "Can export WorkOrder: #{ability.can?(:export, WorkOrder)}"
  puts "Can export :all: #{ability.can?(:export, :all)}"
  puts "Can download :all: #{ability.can?(:download, :all)}"
else
  puts 'ERROR: Admin user not found!'
end

# Test 2: Check if there are any AuditWorkOrder records
puts "\n2. Testing data availability..."
audit_count = AuditWorkOrder.count
puts "AuditWorkOrder count: #{audit_count}"

if audit_count > 0
  puts "First record ID: #{AuditWorkOrder.first.id}"
else
  puts 'WARNING: No AuditWorkOrder records found!'
end

# Test 3: Test the export functionality directly
puts "\n3. Testing export functionality..."
begin
  require 'csv'
  require 'rubyXL'

  # Create a simple test CSV
  test_csv = CSV.generate(headers: true) do |csv|
    csv << ['ID', 'Status', 'Created At']
    csv << ['1', 'pending', '2023-12-25 10:00:00']
    csv << ['2', 'approved', '2023-12-26 11:00:00']
  end

  puts 'Test CSV generated successfully'

  # Test Excel generation
  csv_parsed = CSV.parse(test_csv, headers: true)
  puts "CSV parsed successfully, headers: #{csv_parsed.headers}"

  # Test RubyXL functionality
  workbook = RubyXL::Workbook.new
  worksheet = workbook[0]
  worksheet.add_cell(0, 0, 'Test')
  excel_data = workbook.stream.read
  puts "Excel generation successful, size: #{excel_data.bytesize} bytes"
rescue StandardError => e
  puts "ERROR in export functionality: #{e.message}"
  puts e.backtrace.first(5)
end

# Test 4: Check ActiveAdmin configuration
puts "\n4. Testing ActiveAdmin configuration..."
begin
  # Check if our initializer is loaded
  if ActiveAdmin::ResourceController.instance_methods.include?(:handle_excel_export)
    puts 'Excel export handler is loaded'
  else
    puts 'WARNING: Excel export handler not found'
  end

  # Check download links configuration
  config = ActiveAdmin.application.namespaces[:admin]
  puts "Download links configured: #{config.download_links.inspect}"
rescue StandardError => e
  puts "ERROR checking ActiveAdmin config: #{e.message}"
end

# Test 5: Simulate a request
puts "\n5. Testing request simulation..."
begin
  # Create a mock request
  require 'action_controller'
  require 'action_dispatch'

  # Check if we can create a controller instance
  controller_class = Class.new(ActiveAdmin::ResourceController)
  controller = controller_class.new

  puts 'Controller created successfully'
  puts "Available methods: #{controller.class.instance_methods.grep(/csv|excel|export/).sort}"
rescue StandardError => e
  puts "ERROR in request simulation: #{e.message}"
end

puts "\n=== Test Complete ==="
