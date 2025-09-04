# lib/capistrano/tasks/puma.rake
namespace :puma do
  desc 'Start Puma'
  task :start do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, "exec puma -C #{shared_path}/config/puma.rb --pidfile #{shared_path}/tmp/pids/puma.pid --redirect-stdout #{shared_path}/log/puma.stdout.log --redirect-stderr #{shared_path}/log/puma.stderr.log &"
        end
      end
    end
  end

  desc 'Stop Puma'
  task :stop do
    on roles(:app) do
      # Using a command that won't fail if the pid file doesn't exist
      execute "if [ -f #{shared_path}/tmp/pids/puma.pid ]; then kill -QUIT `cat #{shared_path}/tmp/pids/puma.pid}`; fi"
    end
  end

  desc 'Restart Puma'
  task :restart do
    on roles(:app) do
      invoke 'puma:stop'
      invoke 'puma:start'
    end
  end
end