#!/usr/bin/env ruby

puts '=== PRODUCTION DATABASE CONNECTION DIAGNOSTIC ==='
puts "Time: #{Time.now}"
puts

# Check environment variables
puts '1. ENVIRONMENT VARIABLES:'
puts "RAILS_ENV: #{ENV['RAILS_ENV'] || 'NOT SET'}"
puts "SCI2_DATABASE_USERNAME: #{ENV['SCI2_DATABASE_USERNAME'] ? 'SET' : 'NOT SET'}"
puts "SCI2_DATABASE_PASSWORD: #{ENV['SCI2_DATABASE_PASSWORD'] ? 'SET' : 'NOT SET'}"
puts "DATABASE_URL: #{ENV['DATABASE_URL'] || 'NOT SET'}"
puts

# Check database.yml content
puts '2. DATABASE.YML PRODUCTION CONFIG:'
require 'yaml'
begin
  db_config = YAML.load_file('config/database.yml')
  production_config = db_config['production']
  puts "Adapter: #{production_config['adapter']}"
  puts "Database: #{production_config['database']}"
  puts "Host: #{production_config['host']}"
  puts "Username: #{production_config['username'] || 'FROM ENV VAR'}"
  puts "Password: #{production_config['password'] ? 'SET' : 'FROM ENV VAR'}"
rescue StandardError => e
  puts "Error reading database.yml: #{e.message}"
end
puts

# Check if SQLite files exist in production
puts '3. SQLITE FILES CHECK:'
sqlite_files = ['db/sci2_development.sqlite3', 'db/sci2_test.sqlite3', 'db/sci2_production.sqlite3']
sqlite_files.each do |file|
  if File.exist?(file)
    size = File.size(file)
    puts "#{file}: EXISTS (#{size} bytes)"
  else
    puts "#{file}: NOT FOUND"
  end
end
puts

# Check current working directory and shared paths
puts '4. DEPLOYMENT PATHS:'
puts "Current directory: #{Dir.pwd}"
puts 'Shared path should be: /var/www/sci2/shared'
puts 'Current path should be: /var/www/sci2/current'
puts

# Check if we can determine the actual database being used
puts '5. RAILS DATABASE CONNECTION TEST:'
puts 'Run this on production server:'
puts 'cd /var/www/sci2/current && RAILS_ENV=production bundle exec rails runner "puts ActiveRecord::Base.connection.current_database"'
puts 'cd /var/www/sci2/current && RAILS_ENV=production bundle exec rails runner "puts ActiveRecord::Base.connection.adapter_name"'
puts 'cd /var/www/sci2/current && RAILS_ENV=production bundle exec rails runner "puts Reimbursement.count"'

puts
puts '=== END DIAGNOSTIC ==='
