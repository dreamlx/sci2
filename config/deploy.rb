# config valid for current version and patch releases of Capistrano
lock "~> 3.19.2"

set :application, "sci2"
# 使用copy策略，不依赖Git仓库
set :scm, :copy
set :repository, "."
set :deploy_via, :copy
set :copy_strategy, :export
set :copy_remote_dir, "/tmp"
set :copy_cache, true
set :copy_exclude, %w[.git .gitignore README.md db/*.sqlite3 tmp/ log/ spec/ test/ .DS_Store]

# 添加详细日志输出
set :log_level, :debug
set :format, :pretty
set :format_options, command_output: true, log_file: 'log/capistrano.log', color: :auto, truncate: :auto

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp
set :branch, 'main'  # Update to your main branch name

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/opt/sci2"

# Default value for :format is :airbrussh
# set :format, :airbrussh

# Default value for :pty is true
set :pty, true

# Default value for :linked_files is []
append :linked_files, "config/database.yml", "config/master.key"

# Default value for linked_dirs is []
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "storage"

# Exclude SQLite database files from deployment
set :copy_exclude, %w[
  .git
  .gitignore
  README.md
  db/*.sqlite3
  db/sci2_development.sqlite3
  db/sci2_test.sqlite3
  db/sci2_production.sqlite3
  tmp/
  log/
  spec/
  test/
]

# Bundler options
set :bundle_flags, '--quiet'
set :bundle_jobs, 4
set :bundle_without, %w{test}.join(' ')
set :bundle_path, -> { shared_path.join('bundle') }
set :bundle_binstubs, -> { shared_path.join('bin') }
set :bundle_roles, :all
set :bundle_bins, %w(gem rake rails)
set :bundle_env_variables, { BUNDLE_IGNORE_CONFIG: '1', RAILS_ENV: 'production' }

# RVM Configuration
set :rvm_type, :system
set :rvm_ruby_version, '3.4.2'

# Puma Configuration
set :puma_threads, [4, 16]
set :puma_workers, 2
set :puma_bind, "tcp://0.0.0.0:3000"
set :puma_state, "#{shared_path}/tmp/pids/puma.state"
set :puma_pid, "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.access.log"
set :puma_error_log, "#{release_path}/log/puma.error.log"
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, true

# Skip assets precompilation to avoid JavaScript build issues
set :assets_roles, []

# Custom tasks
namespace :deploy do
  desc 'Debug: Show deployment information'
  task :debug_info do
    on roles(:all) do
      info "=== 部署调试信息 ==="
      info "目标服务器: #{host}"
      info "用户: #{host.user}"
      info "部署路径: #{fetch(:deploy_to)}"
      info "应用名称: #{fetch(:application)}"
      info "Git仓库: #{fetch(:repo_url)}"
      info "分支: #{fetch(:branch)}"
      info "复制策略: #{fetch(:copy_strategy)}"
      info "临时目录: #{fetch(:copy_remote_dir)}"
      
      execute :pwd
      execute :whoami
      execute :ls, "-la /tmp"
      execute :df, "-h"
    end
  end

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke! 'puma:restart'
    end
  end

  desc 'Setup environment variables'
  task :setup_environment do
    on roles(:app) do
      # Create environment file with database credentials
      execute :mkdir, "-p #{shared_path}/config"
      
      # Check if environment variables are set, if not prompt for them
      db_username = fetch(:database_username, nil)
      db_password = fetch(:database_password, nil)
      
      if db_username.nil? || db_password.nil?
        puts "Database credentials not set. Please set them in config/deploy/production.rb:"
        puts "set :database_username, 'your_mysql_username'"
        puts "set :database_password, 'your_mysql_password'"
        exit 1
      end
      
      # Create environment file
      env_content = <<~ENV
        export SCI2_DATABASE_USERNAME='#{db_username}'
        export SCI2_DATABASE_PASSWORD='#{db_password}'
        export RAILS_ENV=production
      ENV
      
      upload! StringIO.new(env_content), "#{shared_path}/config/environment"
      execute :chmod, "600 #{shared_path}/config/environment"
    end
  end

  desc 'Upload config files'
  task :upload_config_files do
    on roles(:app) do
      upload! 'config/database.yml', "#{shared_path}/config/database.yml"
      upload! 'config/master.key', "#{shared_path}/config/master.key"
    end
  end

  desc 'Setup database'
  task :setup_database do
    on roles(:db) do
      within release_path do
        # Source environment variables
        execute :bash, "-c 'source #{shared_path}/config/environment && cd #{release_path} && bundle exec rails db:create RAILS_ENV=production'"
        execute :bash, "-c 'source #{shared_path}/config/environment && cd #{release_path} && bundle exec rails db:migrate RAILS_ENV=production'"
      end
    end
  end

  desc 'Open firewall port'
  task :open_firewall_port do
    on roles(:app) do
      execute "ufw allow 3000/tcp || true"
      execute "firewall-cmd --permanent --add-port=3000/tcp || true"
      execute "firewall-cmd --reload || true"
    end
  end

  before :starting, :upload_config_files
  before :starting, :setup_environment
  after 'deploy:migrate', :setup_database
  after :finishing, :open_firewall_port
end

after 'deploy:finishing', 'deploy:restart'