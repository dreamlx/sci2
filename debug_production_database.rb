#!/usr/bin/env ruby

# Debug script to check production database status
puts "=== Production Database Debug Script ==="
puts "Time: #{Time.now}"
puts

# Check if we're in production environment
puts "1. Environment Check:"
puts "RAILS_ENV: #{ENV['RAILS_ENV'] || 'not set'}"
puts "Rails.env: #{defined?(Rails) ? Rails.env : 'Rails not loaded'}"
puts

# Check database configuration
puts "2. Database Configuration:"
puts "SCI2_DATABASE_USERNAME: #{ENV['SCI2_DATABASE_USERNAME'] ? 'set' : 'NOT SET'}"
puts "SCI2_DATABASE_PASSWORD: #{ENV['SCI2_DATABASE_PASSWORD'] ? 'set' : 'NOT SET'}"
puts

# Check for existing data
if defined?(Rails)
  Rails.application.initialize!
  
  puts "3. Database Connection:"
  begin
    puts "Database adapter: #{ActiveRecord::Base.connection.adapter_name}"
    puts "Database name: #{ActiveRecord::Base.connection.current_database}"
    puts
    
    puts "4. Data Check:"
    if defined?(AdminUser)
      admin_count = AdminUser.count
      puts "AdminUser count: #{admin_count}"
      if admin_count > 0
        puts "First admin user: #{AdminUser.first.email}"
      end
    end
    
    if defined?(Reimbursement)
      reimbursement_count = Reimbursement.count
      puts "Reimbursement count: #{reimbursement_count}"
    end
    
    if defined?(WorkOrder)
      work_order_count = WorkOrder.count
      puts "WorkOrder count: #{work_order_count}"
    end
    
  rescue => e
    puts "Database connection error: #{e.message}"
  end
else
  puts "Rails not available - run with: RAILS_ENV=production rails runner debug_production_database.rb"
end

puts
puts "=== End Debug Script ==="