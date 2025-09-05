# lib/capistrano/tasks/puma.rake
namespace :puma do
  desc 'Start Puma'
  task :start do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          info "Starting Puma server in background..."
          execute "/usr/local/rvm/bin/rvm", "3.4.2 do bundle exec puma -C config/puma.rb --pidfile #{shared_path}/tmp/pids/puma.pid --redirect-stdout #{shared_path}/log/puma.stdout.log --redirect-stderr #{shared_path}/log/puma.stderr.log", in: :background
          sleep 2  # Give Puma time to start
          info "Puma server started successfully in background"
          info "Check server status with: cap production server:check_puma"
        end
      end
    end
  end

  desc 'Stop Puma'
  task :stop do
    on roles(:app) do
      # Using a command that won't fail if the pid file doesn't exist
      execute "if [ -f #{shared_path}/tmp/pids/puma.pid ]; then kill -QUIT $(cat #{shared_path}/tmp/pids/puma.pid); fi"
    end
  end

  desc 'Restart Puma'
  task :restart do
    on roles(:app) do
      info "Restarting Puma server..."
      invoke 'puma:stop'
      sleep 1  # Give time for graceful shutdown
      invoke 'puma:start'
      info "Puma server restart completed"
    end
  end
end