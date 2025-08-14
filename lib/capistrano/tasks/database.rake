namespace :database do
  desc 'Create MySQL database and user for production'
  task :create_mysql_setup do
    on roles(:db) do
      # Get database credentials
      db_username = fetch(:database_username)
      db_password = fetch(:database_password)
      
      puts "Setting up MySQL database and user..."
      
      # Create database and user (requires MySQL root access)
      mysql_commands = <<~SQL
        CREATE DATABASE IF NOT EXISTS sci2_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS '#{db_username}'@'localhost' IDENTIFIED BY '#{db_password}';
        GRANT ALL PRIVILEGES ON sci2_production.* TO '#{db_username}'@'localhost';
        FLUSH PRIVILEGES;
      SQL
      
      # Save commands to a temporary file
      temp_sql_file = "/tmp/setup_sci2_db.sql"
      upload! StringIO.new(mysql_commands), temp_sql_file
      
      # Execute MySQL commands
      begin
        execute :mysql, "-u root -p < #{temp_sql_file}"
        puts "✅ MySQL database and user created successfully"
      rescue => e
        puts "❌ Failed to create MySQL database. Please run manually:"
        puts "mysql -u root -p"
        puts mysql_commands
        puts "Error: #{e.message}"
      ensure
        # Clean up temporary file
        execute :rm, "-f #{temp_sql_file}"
      end
    end
  end

  desc 'Test database connection'
  task :test_connection do
    on roles(:db) do
      within release_path do
        # Source environment variables and test connection
        test_command = <<~BASH
          source #{shared_path}/config/environment && \
          cd #{release_path} && \
          bundle exec rails runner "
            begin
              puts 'Testing database connection...'
              puts 'Adapter: ' + ActiveRecord::Base.connection.adapter_name
              puts 'Database: ' + ActiveRecord::Base.connection.current_database
              puts 'Connection successful!'
            rescue => e
              puts 'Connection failed: ' + e.message
              exit 1
            end
          " RAILS_ENV=production
        BASH
        
        execute :bash, "-c '#{test_command}'"
      end
    end
  end

  desc 'Reset production database (DANGEROUS - removes all data)'
  task :reset_production do
    on roles(:db) do
      within release_path do
        puts "⚠️  WARNING: This will destroy all data in the production database!"
        puts "Are you sure you want to continue? (Type 'YES' to confirm)"
        
        # In a real scenario, you might want to add confirmation
        # For now, we'll just show the commands that would be run
        puts "To reset the database manually, run:"
        puts "cd #{release_path}"
        puts "source #{shared_path}/config/environment"
        puts "bundle exec rails db:drop RAILS_ENV=production"
        puts "bundle exec rails db:create RAILS_ENV=production"
        puts "bundle exec rails db:migrate RAILS_ENV=production"
      end
    end
  end
end

# Hook into deployment process
before 'deploy:migrate', 'database:create_mysql_setup'
after 'deploy:migrate', 'database:test_connection'