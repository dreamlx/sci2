# lib/capistrano/tasks/debug.rake
# This file can be used to add temporary debugging tasks.

namespace :debug do
  desc 'Check Rails production logs for errors'
  task :check_rails_logs do
    on roles(:app) do
      execute "tail -50 #{shared_path}/log/production.log || echo 'Production log not found'"
    end
  end

  desc 'Check Rails application status'
  task :check_app_status do
    on roles(:app) do
      execute "curl -I http://localhost:3000/admin/ || echo 'Failed to connect to app'"
    end
  end

  desc 'Check database connection'
  task :check_database do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, :exec, :rails, 'runner', '"puts ActiveRecord::Base.connection.active? ? \"Database connected\" : \"Database not connected\""'
        end
      end
    end
  end

  desc 'Check admin page content'
  task :check_admin_page do
    on roles(:app) do
      execute "curl -L http://localhost:3000/admin/ | head -50 || echo 'Failed to get page content'"
    end
  end

  desc 'Check if admin users exist'
  task :check_admin_users do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, :exec, :rails, 'runner', '"puts \"Admin users count: #{AdminUser.count}\""'
        end
      end
    end
  end

  desc 'Create admin users from seed data'
  task :create_admin_users do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, :exec, :rails, 'runner', '"load \"db/seeds/admin_users_seed.rb\""'
        end
      end
    end
  end

  desc 'Check production log for recent errors'
  task :check_production_log do
    on roles(:app) do
      execute "ls -la #{shared_path}/log/ || echo 'Log directory not found'"
      execute "tail -50 #{shared_path}/log/production.log || echo 'Production log not found'"
    end
  end

  desc 'Check detailed Puma logs for errors'
  task :check_puma_errors do
    on roles(:app) do
      execute "echo '=== Recent Puma stdout errors ==='"
      execute "tail -100 #{shared_path}/log/puma.stdout.log | grep -i error || echo 'No errors found in stdout'"
      execute "echo '=== Recent Puma stderr ==='"
      execute "tail -50 #{shared_path}/log/puma.stderr.log || echo 'No stderr log'"
      execute "echo '=== Last 30 lines of Puma stdout ==='"
      execute "tail -30 #{shared_path}/log/puma.stdout.log"
    end
  end

  desc "Get detailed error information from Puma logs"
  task :get_detailed_errors do
    on roles(:app) do
      execute "echo '=== Searching for complete error messages ==='"
      execute "grep -A 5 -B 5 'Error\\|Exception\\|undefined method\\|NoMethodError\\|NameError' #{shared_path}/log/puma.stdout.log | tail -50 || echo 'No detailed errors found'"
      
      execute "echo '=== Last 100 lines of Puma stdout for full context ==='"
      execute "tail -100 #{shared_path}/log/puma.stdout.log"
      
      execute "echo '=== Check if there are any Rails application errors ==='"
      execute "grep -i 'started\\|completed\\|error\\|exception' #{shared_path}/log/puma.stdout.log | tail -20 || echo 'No Rails request logs found'"
    end
  end

  desc "Check asset precompilation status"
  task :check_assets do
    on roles(:app) do
      execute "echo '=== Checking public/assets directory ==='"
      execute "ls -la #{current_path}/public/assets/ | head -20 || echo 'Assets directory not found'"
      
      execute "echo '=== Looking for Active Admin CSS files ==='"
      execute "find #{current_path}/public/assets/ -name '*active_admin*' -type f || echo 'No Active Admin assets found'"
      
      execute "echo '=== Checking asset manifest ==='"
      execute "ls -la #{current_path}/public/assets/.sprockets-manifest* || echo 'No manifest found'"
      execute "head -20 #{current_path}/public/assets/.sprockets-manifest* || echo 'Cannot read manifest'"
      
      execute "echo '=== Checking if assets are precompiled ==='"
      execute "ls -la #{current_path}/public/assets/ | wc -l"
    end
  end

  desc "Precompile assets in production"
  task :precompile_assets do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute "echo '=== Starting asset precompilation ==='"
          execute :bundle, :exec, :rails, 'assets:precompile'
          
          execute "echo '=== Checking precompiled assets ==='"
          execute "ls -la #{current_path}/public/assets/ | head -10"
          execute "find #{current_path}/public/assets/ -name '*active_admin*' -type f | head -5 || echo 'Still no Active Admin assets'"
        end
      end
    end
  end

  desc "Check and install Node.js/npm"
  task :check_nodejs do
    on roles(:app) do
      execute "echo '=== Checking Node.js and npm ==='"
      execute "node --version || echo 'Node.js not installed'"
      execute "npm --version || echo 'npm not installed'"
      
      execute "echo '=== Checking if Node.js is available in PATH ==='"
      execute "which node || echo 'node not in PATH'"
      execute "which npm || echo 'npm not in PATH'"
      
      execute "echo '=== Installing Node.js via NodeSource repository ==='"
      execute "curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
      execute "sudo apt-get install -y nodejs"
      
      execute "echo '=== Verifying installation ==='"
      execute "node --version"
      execute "npm --version"
    end
  
    desc "Check JavaScript files structure"
    task :check_js_files do
      on roles(:app) do
        within release_path do
          execute "echo '=== Checking JavaScript files structure ==='"
          execute "find app/javascript -type f -name '*.js' | head -20 || echo 'No JS files found'"
          execute "echo '=== Checking controllers/index.js ==='"
          execute "cat app/javascript/controllers/index.js || echo 'index.js not found'"
          execute "echo '=== Checking application.js ==='"
          execute "cat app/javascript/application.js || echo 'application.js not found'"
        end
      
        desc "Fix JavaScript files structure"
        task :fix_js_files do
          on roles(:app) do
            within release_path do
              execute "echo '=== Fixing JavaScript files structure ==='"
              
              # Fix controllers/index.js
              execute "echo '=== Fixing controllers/index.js ==='"
              execute <<~SCRIPT
                cat > app/javascript/controllers/index.js << 'EOF'
      // Import and register all your controllers from the importmap via controllers/**/*_controller
      import { application } from "./application"
      
      // Configure Stimulus development experience
      application.debug = false
      window.Stimulus = application
      
      export { application }
      EOF
              SCRIPT
              
              execute "echo '=== Verifying fixed files ==='"
              execute "cat app/javascript/controllers/index.js"
            end
          end
        end
      end
    end
  end

  desc "Install missing JavaScript dependencies"
  task :install_js_dependencies do
    on roles(:app) do
      within current_path do
        execute "echo '=== Installing missing JavaScript dependencies ==='"
        execute "npm install @hotwired/stimulus"
        
        execute "echo '=== Checking if controllers/application.js exists ==='"
        execute "ls -la app/javascript/controllers/ || echo 'Controllers directory not found'"
        
        execute "echo '=== Creating missing controller files if needed ==='"
        execute "mkdir -p app/javascript/controllers"
        execute "test -f app/javascript/controllers/application.js || echo 'import { Application } from \"@hotwired/stimulus\"\n\nconst application = Application.start()\n\nexport { application }' > app/javascript/controllers/application.js"
        
        execute "echo '=== Verifying package.json and dependencies ==='"
        execute "cat package.json || echo 'No package.json found'"
        execute "npm list --depth=0 || echo 'No node_modules found'"
      end
    end
  
    desc "Fix JavaScript files by copying correct content to production server"
    task :fix_js_files do
      on roles(:app) do
        within current_path do
          execute "echo '=== Fixing JavaScript files on production server ==='"
          
          execute "echo '=== Creating controllers directory ==='"
          execute "mkdir -p app/javascript/controllers"
          
          execute "echo '=== Creating fixed index.js file ==='"
          execute %Q{cat > app/javascript/controllers/index.js << 'EOF'
  // Import and register all your controllers from the importmap via controllers/**/*_controller
  import { application } from "./application"
  
  // Configure Stimulus development experience
  application.debug = false
  window.Stimulus = application
  
  export { application }
  EOF}
          
          execute "echo '=== Verifying fixed files ==='"
          execute "cat app/javascript/controllers/index.js"
          
          execute "echo '=== Checking file permissions ==='"
          execute "ls -la app/javascript/controllers/"
        end
      end
    end
  end

  desc "Check JavaScript files on production server"
  task :check_js_files do
    on roles(:app) do
      within current_path do
        execute "echo '=== Checking JavaScript files on production server ==='"
        
        execute "echo '=== Contents of app/javascript/controllers/index.js ==='"
        execute "cat app/javascript/controllers/index.js || echo 'index.js not found'"
        
        execute "echo '=== Contents of app/javascript/controllers/application.js ==='"
        execute "cat app/javascript/controllers/application.js || echo 'application.js not found'"
        
        execute "echo '=== Checking package.json ==='"
        execute "cat package.json | grep -A5 -B5 'hotwired' || echo 'No hotwired dependencies found'"
        
        execute "echo '=== Checking node_modules ==='"
        execute "ls -la node_modules/@hotwired/ || echo 'No @hotwired modules found'"
        
        execute "echo '=== Git status ==='"
        execute "git log --oneline -5 || echo 'Git log not available'"
        execute "git status || echo 'Git status not available'"
      end
    end
  end

  desc "Check deployment directory structure"
  task :check_deployment_structure do
    on roles(:app) do
      execute "echo '=== Checking deployment directory structure ==='"
      
      execute "echo '=== Current working directory ==='"
      execute "pwd"
      
      execute "echo '=== Directory listing ==='"
      execute "ls -la"
      
      execute "echo '=== Checking /opt/sci2 structure ==='"
      execute "ls -la /opt/sci2/ || echo '/opt/sci2 not found'"
      
      execute "echo '=== Checking current release ==='"
      execute "ls -la /opt/sci2/current/ || echo '/opt/sci2/current not found'"
      
      execute "echo '=== Checking releases directory ==='"
      execute "ls -la /opt/sci2/releases/ || echo '/opt/sci2/releases not found'"
      

    end
  end

  desc "Check actual index.js file content on production server"
  task :check_index_js_content do
    on roles(:app) do
      execute "echo '=== Checking actual index.js file content ==='"
      
      execute "echo '=== Direct file check ==='"
      execute "cat /opt/sci2/current/app/javascript/controllers/index.js || echo 'File not found at absolute path'"
      
      execute "echo '=== File size and permissions ==='"
      execute "ls -la /opt/sci2/current/app/javascript/controllers/index.js || echo 'Cannot stat file'"
      
      execute "echo '=== Directory contents ==='"
      execute "ls -la /opt/sci2/current/app/javascript/controllers/ || echo 'Directory not found'"
      
      execute "echo '=== Current path verification ==='"
      execute "echo 'Current path should be:' && readlink /opt/sci2/current"
      
      execute "echo '=== Checking if current is a symlink ==='"
      execute "readlink /opt/sci2/current || echo 'current is not a symlink'"
      
      execute "echo '=== Checking JavaScript directory in current release ==='"
      execute "ls -la /opt/sci2/current/app/javascript/controllers/ || echo 'JavaScript controllers directory not found'"
    end
  end
end