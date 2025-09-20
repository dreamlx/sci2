# lib/capistrano/tasks/puma.rake
namespace :puma do
  desc 'Check port availability'
  task :check_port do
    on roles(:app) do
      info "Checking if port 3000 is available..."
      port_check = capture("netstat -tuln | grep ':3000 ' || echo 'PORT_FREE'")
      if port_check.include?('PORT_FREE')
        info "✓ Port 3000 is available"
      else
        warn "⚠ Port 3000 is occupied:"
        info port_check
        
        # Find processes using port 3000
        processes = capture("lsof -ti:3000 || echo 'NO_PROCESSES'")
        unless processes.include?('NO_PROCESSES')
          info "Processes using port 3000: #{processes}"
        end
      end
    end
  end

  desc 'Force kill processes on port 3000'
  task :force_kill_port do
    on roles(:app) do
      info "Force killing any processes on port 3000..."
      execute "lsof -ti:3000 | xargs -r kill -9 || true"
      sleep 2
      info "Port cleanup completed"
    end
  end

  desc 'Stop Puma gracefully with fallback'
  task :stop do
    on roles(:app) do
      info "Stopping Puma server..."
      
      # Step 1: Try graceful shutdown via PID file
      if test("[ -f #{shared_path}/tmp/pids/puma.pid ]")
        pid = capture("cat #{shared_path}/tmp/pids/puma.pid")
        info "Found Puma PID: #{pid}"
        
        # Try graceful shutdown
        execute "kill -QUIT #{pid} || true"
        sleep 3
        
        # Check if process still exists
        if test("kill -0 #{pid} 2>/dev/null")
          warn "Graceful shutdown failed, trying TERM signal..."
          execute "kill -TERM #{pid} || true"
          sleep 2
          
          # Final check and force kill if needed
          if test("kill -0 #{pid} 2>/dev/null")
            warn "TERM signal failed, force killing..."
            execute "kill -9 #{pid} || true"
          end
        end
        
        # Remove PID file
        execute "rm -f #{shared_path}/tmp/pids/puma.pid"
      else
        info "No PID file found"
      end
      
      # Step 2: Clean up any remaining processes on port 3000
      invoke 'puma:force_kill_port'
      
      # Step 3: Verify port is free
      invoke 'puma:check_port'
    end
  end

  desc 'Start Puma with port verification'
  task :start do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          # Ensure port is available before starting
          invoke 'puma:check_port'
          
          info "Starting Puma server in background..."
          execute "/usr/local/rvm/bin/rvm", "3.4.2 do bundle exec puma -C config/puma.rb --pidfile #{shared_path}/tmp/pids/puma.pid --redirect-stdout #{shared_path}/log/puma.stdout.log --redirect-stderr #{shared_path}/log/puma.stderr.log", in: :background
          
          # Wait and verify startup
          sleep 5
          
          if test("[ -f #{shared_path}/tmp/pids/puma.pid ]")
            pid = capture("cat #{shared_path}/tmp/pids/puma.pid")
            if test("kill -0 #{pid} 2>/dev/null")
              info "✓ Puma server started successfully (PID: #{pid})"
              
              # Verify port is bound
              sleep 2
              port_check = capture("netstat -tuln | grep ':3000 ' || echo 'PORT_NOT_BOUND'")
              if port_check.include?('PORT_NOT_BOUND')
                error "✗ Puma started but port 3000 is not bound!"
              else
                info "✓ Port 3000 is properly bound"
              end
            else
              error "✗ Puma process not running after start"
            end
          else
            error "✗ PID file not created"
          end
          
          info "Check server status with: cap production server:check_puma"
        end
      end
    end
  end

  desc 'Restart Puma with enhanced error handling'
  task :restart do
    on roles(:app) do
      info "Restarting Puma server with enhanced error handling..."
      
      # Enhanced stop with verification
      invoke 'puma:stop'
      
      # Additional wait time for complete cleanup
      info "Waiting for complete cleanup..."
      sleep 3
      
      # Final port verification before start
      invoke 'puma:check_port'
      
      # Start with verification
      invoke 'puma:start'
      
      info "✓ Puma server restart completed successfully"
    end
  end

  desc 'Show Puma status and diagnostics'
  task :status do
    on roles(:app) do
      info "=== Puma Status Diagnostics ==="
      
      # Check PID file
      if test("[ -f #{shared_path}/tmp/pids/puma.pid ]")
        pid = capture("cat #{shared_path}/tmp/pids/puma.pid")
        info "PID file exists: #{pid}"
        
        if test("kill -0 #{pid} 2>/dev/null")
          info "✓ Process #{pid} is running"
        else
          warn "✗ Process #{pid} is not running (stale PID file)"
        end
      else
        info "No PID file found"
      end
      
      # Check port
      invoke 'puma:check_port'
      
      # Check logs
      if test("[ -f #{shared_path}/log/puma.stdout.log ]")
        info "Recent stdout log:"
        execute "tail -10 #{shared_path}/log/puma.stdout.log || true"
      end
      
      if test("[ -f #{shared_path}/log/puma.stderr.log ]")
        info "Recent stderr log:"
        execute "tail -10 #{shared_path}/log/puma.stderr.log || true"
      end
    end
  end
end