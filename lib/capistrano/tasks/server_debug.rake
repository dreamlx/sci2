# lib/capistrano/tasks/server_debug.rake
namespace :server do
  desc 'Check Puma process status'
  task :check_puma do
    on roles(:app) do
      execute "ps aux | grep puma | grep -v grep || echo 'No puma processes found'"
    end
  end

  desc 'Check Puma logs'
  task :check_logs do
    on roles(:app) do
      execute "ls -la #{shared_path}/log/ || echo 'Log directory not found'"
      execute "tail -20 #{shared_path}/log/puma.stdout.log || echo 'Puma stdout log not found'"
      execute "tail -20 #{shared_path}/log/puma.stderr.log || echo 'Puma stderr log not found'"
    end
  end

  desc 'Check application directory'
  task :check_app do
    on roles(:app) do
      execute "ls -la #{current_path} || echo 'Current path not found'"
      execute "ls -la #{shared_path} || echo 'Shared path not found'"
    end
  end

  desc 'Manual start Puma for debugging'
  task :manual_start do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, "exec puma -C #{shared_path}/config/puma.rb"
        end
      end
    end
  end

  desc 'Check Rails environment and dependencies'
  task :check_rails do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute "echo 'Checking Rails environment...'"
          execute :bundle, "exec rails --version || echo 'Rails command failed'"
          execute :bundle, "exec rake --version || echo 'Rake command failed'"
          execute "echo 'Checking database configuration...'"
          execute :bundle, "exec rails runner 'puts Rails.env' || echo 'Rails runner failed'"
          execute "echo 'Checking if database exists...'"
          execute :bundle, "exec rake db:version || echo 'Database check failed'"
        end
      end
    end
  end

  desc 'Check Puma configuration'
  task :check_puma_config do
    on roles(:app) do
      execute "cat #{shared_path}/config/puma.rb || echo 'Puma config not found'"
      execute "ls -la #{shared_path}/tmp/pids/ || echo 'PID directory not found'"
    end
  end
end