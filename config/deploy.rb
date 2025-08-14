# config valid for current version and patch releases of Capistrano
lock "~> 3.19.2"

set :application, "sci2"
set :repo_url, "https://github.com/dreamlx/sci2.git"  # Use HTTPS URL instead of SSH URL

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

# Custom tasks
namespace :deploy do
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke! 'puma:restart'
    end
  end

  desc 'Upload config files'
  task :upload_config_files do
    on roles(:app) do
      upload! 'config/database.yml', "#{shared_path}/config/database.yml"
      upload! 'config/master.key', "#{shared_path}/config/master.key"
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
  after :finishing, :open_firewall_port
end

after 'deploy:finishing', 'deploy:restart'