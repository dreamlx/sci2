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
        # 使用 sudo mysql 访问 root 用户（Ubuntu 默认配置）
        execute :sudo, :mysql, "-u root < #{temp_sql_file}"
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
        # Source environment variables and test connection
        runner_command = <<~RUBY
          begin
            puts 'Testing database connection...'
            puts 'Adapter: ' + ActiveRecord::Base.connection.adapter_name
            if ActiveRecord::Base.connection.adapter_name != 'SQLite'
              puts 'Database: ' + ActiveRecord::Base.connection.current_database
            end
            puts 'Connection successful!'
          rescue => e
            puts 'Connection failed: ' + e.message
            exit 1
          end
        RUBY
        
        execute :rvm, fetch(:rvm_ruby_version), :do, :bundle, :exec, :rails, :runner, "\"#{runner_command}\"", "RAILS_ENV=production"
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

  desc 'Setup development database symlink'
  task :setup_development_symlink do
    on roles(:db) do
      within release_path do
        # Create shared database directory if it doesn't exist
        execute :mkdir, '-p', "#{shared_path}/db"
        
        # Remove existing development database file if it exists
        execute :rm, '-f', "#{release_path}/db/sci2_development.sqlite3"
        
        # Create symlink to shared development database
        shared_dev_db = "#{shared_path}/db/sci2_development.sqlite3"
        release_dev_db = "#{release_path}/db/sci2_development.sqlite3"
        
        # Create empty database file in shared location if it doesn't exist
        execute :touch, shared_dev_db
        
        # Create the symlink
        execute :ln, '-sf', shared_dev_db, release_dev_db
        
        puts "✅ Created symlink: #{release_dev_db} -> #{shared_dev_db}"
      end
    end
  end

  desc 'Copy production database to development database'
  task :copy_production_to_development do
    on roles(:db) do
      within release_path do
        # Path to production and development databases
        prod_db = "#{shared_path}/db/sci2_production.sqlite3"
        dev_db = "#{shared_path}/db/sci2_development.sqlite3"
        
        # Check if production database exists
        if test("[ -f #{prod_db} ]")
          puts "📋 Copying production database to development..."
          execute :cp, prod_db, dev_db
          puts "✅ Successfully copied production database to development"
        else
          puts "⚠️  Production database not found at #{prod_db}"
          puts "Creating empty development database..."
          execute :touch, dev_db
        end
      end
    end
  end
end

# Hook into deployment process
# Only run MySQL setup if adapter is mysql2
if fetch(:database_config, "").include?("mysql2")
  before 'deploy:migrate', 'database:create_mysql_setup'
end

# Setup development database symlink when using development environment
if fetch(:rails_env) == 'development'
  before 'deploy:migrate', 'database:setup_development_symlink'
end

after 'deploy:migrate', 'database:test_connection'