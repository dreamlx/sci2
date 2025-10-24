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

    desc 'Emergency port cleanup - force kill everything on port 3000'
    task :emergency_cleanup do
      on roles(:app) do
        info '=== EMERGENCY PORT 3000 CLEANUP ==='

        # Show what's using the port before cleanup
        info 'Current port 3000 usage:'
        execute "lsof -i:3000 || echo 'No processes using port 3000'"

        # Kill everything using port 3000
        info 'Force killing all processes on port 3000...'
        execute 'lsof -ti:3000 | xargs -r kill -9 || true'

        # Wait and verify
        sleep 3
        info 'Verifying port is free:'
        execute "lsof -i:3000 || echo '✓ Port 3000 is now free'"

        # Clean up PID files
        info 'Cleaning up PID files...'
        execute "rm -f #{shared_path}/tmp/pids/puma.pid"

        info 'Emergency cleanup completed'
      end
    end

    desc 'Check what is using port 3000'
    task :check_port do
      on roles(:app) do
        info '=== PORT 3000 DIAGNOSTIC ==='

        # Check if port is listening
        info 'Port 3000 listening status:'
        execute "netstat -tuln | grep ':3000' || echo 'Port 3000 is not listening'"

        # Check what processes are using the port
        info 'Processes using port 3000:'
        execute "lsof -i:3000 || echo 'No processes using port 3000'"

        # Check for any puma processes
        info 'All puma processes:'
        execute "ps aux | grep puma | grep -v grep || echo 'No puma processes found'"

        # Check PID file status
        if test("[ -f #{shared_path}/tmp/pids/puma.pid ]")
          pid = capture("cat #{shared_path}/tmp/pids/puma.pid")
          info "PID file exists with PID: #{pid}"

          if test("kill -0 #{pid} 2>/dev/null")
            info "✓ Process #{pid} is running"
            execute "ps -p #{pid} -o pid,ppid,cmd,etime || true"
          else
            warn "✗ Process #{pid} is not running (stale PID file)"
          end
        else
          info 'No PID file found'
        end
      end
    end

    desc 'Full system diagnostic for deployment issues'
    task :full_diagnostic do
      on roles(:app) do
        info '=== FULL DEPLOYMENT DIAGNOSTIC ==='

        # System status
        info '=== System Status ==='
        execute 'uptime'
        execute 'free -h'
        execute 'df -h /'

        # Ruby/RVM status
        info '=== Ruby Environment ==='
        execute "/usr/local/rvm/bin/rvm current || echo 'RVM not available'"
        execute "which ruby || echo 'Ruby not found'"
        execute "ruby --version || echo 'Ruby version check failed'"

        # Application status
        info '=== Application Status ==='
        execute "ls -la #{current_path} | head -5 || echo 'Current path not accessible'"
        execute "ls -la #{shared_path} | head -5 || echo 'Shared path not accessible'"

        # Network status
        info '=== Network Status ==='
        execute 'netstat -tuln | grep LISTEN | head -10'

        # Process status
        info '=== Process Status ==='
        execute "ps aux | grep -E '(ruby|puma|rails)' | grep -v grep || echo 'No Ruby processes'"

        # Port 3000 specific
        invoke 'server:check_port'

        # Recent logs
        info '=== Recent Logs ==='
        execute "tail -10 #{shared_path}/log/puma.stdout.log || echo 'No stdout log'"
        execute "tail -10 #{shared_path}/log/puma.stderr.log || echo 'No stderr log'"
      end
    end
  end
end
