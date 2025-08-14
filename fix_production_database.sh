#!/bin/bash

echo "=== PRODUCTION DATABASE FIX SCRIPT ==="
echo "Run this script ON THE PRODUCTION SERVER (8.136.10.88)"
echo

echo "1. First, check current database connection:"
cd /var/www/sci2/current
echo "Current directory: $(pwd)"
echo

echo "2. Check environment variables:"
echo "SCI2_DATABASE_USERNAME: ${SCI2_DATABASE_USERNAME:-NOT SET}"
echo "SCI2_DATABASE_PASSWORD: ${SCI2_DATABASE_PASSWORD:-NOT SET}"
echo

echo "3. Test database connection:"
RAILS_ENV=production bundle exec rails runner "
begin
  puts 'Database adapter: ' + ActiveRecord::Base.connection.adapter_name
  puts 'Database name: ' + ActiveRecord::Base.connection.current_database
  puts 'Reimbursement count: ' + Reimbursement.count.to_s
rescue => e
  puts 'Database connection error: ' + e.message
end
"

echo
echo "4. TO FIX THE ISSUE:"
echo "   a) Set environment variables in /etc/environment or ~/.bashrc:"
echo "      export SCI2_DATABASE_USERNAME='your_mysql_username'"
echo "      export SCI2_DATABASE_PASSWORD='your_mysql_password'"
echo
echo "   b) Create MySQL database:"
echo "      mysql -u root -p -e 'CREATE DATABASE sci2_production;'"
echo
echo "   c) Run migrations on empty MySQL database:"
echo "      cd /var/www/sci2/current"
echo "      RAILS_ENV=production bundle exec rails db:create"
echo "      RAILS_ENV=production bundle exec rails db:migrate"
echo
echo "   d) Restart the application:"
echo "      sudo systemctl restart sci2"  # or whatever your service name is
echo
echo "=== END FIX SCRIPT ==="