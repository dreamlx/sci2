# config valid for current version and patch releases of Capistrano
lock '~> 3.19.2'

set :application, 'sci2'
set :repo_url, 'git@gitee.com:dreamlx/sci2.git'

# Default value for :scm is :git
set :scm, :git

# 添加详细日志输出
set :log_level, :debug
set :format, :pretty
set :format_options, command_output: true, log_file: 'log/capistrano.log', color: :auto, truncate: :auto

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp
set :branch, 'main' # Update to your main branch name

# RVM configuration
set :rvm_type, :system # 使用系统级RVM
set :rvm_ruby_version, '3.4.2' # 指定Ruby版本
# set :rvm_path, '/usr/local/rvm/scripts/rvm' # Let capistrano-rvm detect it automatically

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, '/opt/sci2'

# Default value for :format is :airbrussh
# set :format, :airbrussh

# Default value for :pty is true
set :pty, true

# Default value for :linked_files is []
append :linked_files, 'config/database.yml', 'config/master.key', 'config/puma.rb', 'db/sci2_production.sqlite3'

# Default value for linked_dirs is []
append :linked_dirs, 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'public/system', 'storage'

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
set :bundle_without, %w[test].join(' ')
set :bundle_path, -> { shared_path.join('bundle') }
set :bundle_binstubs, -> { shared_path.join('bin') }
set :bundle_roles, :all
set :bundle_bins, %w[gem rake rails]
set :bundle_env_variables, { BUNDLE_IGNORE_CONFIG: '1', RAILS_ENV: 'production' }

# rbenv Configuration
# set :rbenv_type, :user
# set :rbenv_ruby, '3.4.2'
# set :rbenv_path, '/home/test/.rbenv'
# set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
# set :rbenv_map_bins, %w{rake gem bundle ruby rails}
# set :rbenv_roles, :all

# RVM Configuration
set :rvm_type, :system
set :rvm_ruby_version, '3.4.2'

# Puma Configuration
set :puma_threads, [4, 16]
set :puma_workers, 2
set :puma_bind, 'tcp://0.0.0.0:3000'
set :puma_state, "#{shared_path}/tmp/pids/puma.state"
set :puma_pid, "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.access.log"
set :puma_error_log, "#{release_path}/log/puma.error.log"
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, true

# Default value for :linked_files is []
# append :linked_files, "config/database.yml", 'config/master.key'

# Default value for linked_dirs is []
append :linked_dirs, 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'public/system', 'storage'

# Add this to ensure assets are precompiled during deployment
namespace :deploy do
  after :finishing, 'deploy:assets:precompile'
end

# Custom tasks
namespace :deploy do
  desc 'Manual upload and deploy for firewall environments'
  task :manual_upload do
    on roles(:all) do
      # 创建部署目录结构
      execute :mkdir, "-p #{fetch(:deploy_to)}/shared/config"
      execute :mkdir, "-p #{fetch(:deploy_to)}/shared/log"
      execute :mkdir, "-p #{fetch(:deploy_to)}/shared/tmp/pids"
      execute :mkdir, "-p #{fetch(:deploy_to)}/shared/tmp/cache"
      execute :mkdir, "-p #{fetch(:deploy_to)}/shared/tmp/sockets"
      execute :mkdir, "-p #{fetch(:deploy_to)}/shared/public/system"
      execute :mkdir, "-p #{fetch(:deploy_to)}/shared/storage"
      execute :mkdir, "-p #{fetch(:deploy_to)}/releases"

      # 创建当前发布目录
      release_timestamp = Time.now.strftime('%Y%m%d%H%M%S')
      release_path = "#{fetch(:deploy_to)}/releases/#{release_timestamp}"
      execute :mkdir, "-p #{release_path}"

      info "创建发布目录: #{release_path}"

      # 打包本地代码
      run_locally do
        execute :tar,
                "-czf /tmp/sci2_deploy.tar.gz --exclude='.git' --exclude='tmp' --exclude='log' --exclude='spec' --exclude='test' --exclude='db/*.sqlite3' ."
      end

      # 上传代码包
      upload! '/tmp/sci2_deploy.tar.gz', '/tmp/sci2_deploy.tar.gz'

      # 解压到发布目录
      execute :tar, "-xzf /tmp/sci2_deploy.tar.gz -C #{release_path}"
      execute :rm, '/tmp/sci2_deploy.tar.gz'

      # 创建符号链接
      execute :ln, "-nfs #{release_path} #{fetch(:deploy_to)}/current"

      info "手动部署完成到: #{release_path}"
    end
  end

  desc 'Debug: Show deployment information'
  task :debug_info do
    on roles(:all) do
      info '=== 部署调试信息 ==='
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
      execute :ls, '-la /tmp'
      execute :df, '-h'
    end
  end

  after 'deploy:publishing', 'puma:restart'

  after 'deploy:publishing', 'deploy:restart'

  desc 'Setup environment variables'
  task :setup_environment do
    on roles(:app) do
      # Create environment file with database credentials
      execute :mkdir, "-p #{shared_path}/config"

      # Check if environment variables are set, if not prompt for them
      db_username = fetch(:database_username, nil)
      db_password = fetch(:database_password, nil)

      if db_username.nil? || db_password.nil?
        puts 'Database credentials not set. Please set them in config/deploy/production.rb:'
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
      upload! 'config/puma.rb', "#{shared_path}/config/puma.rb"
    end
  end

  desc 'Setup database'
  task :setup_database do
    on roles(:db) do
      # 确保 shared/db 目录存在
      execute :mkdir, "-p #{shared_path}/db"

      # 检查 shared 路径下的数据库文件是否存在，如果不存在就创建它
      # 这是为了让 Capistrano 的 linked_files 任务能够成功创建符号链接
      if test("[ -f #{shared_path}/db/sci2_production.sqlite3 ]")
        puts '✅ SQLite database already exists in shared path, skipping creation'
      else
        puts '🔧 Touching new SQLite database file in shared path...'
        execute :touch, "#{shared_path}/db/sci2_production.sqlite3"
        execute :chmod, '664', "#{shared_path}/db/sci2_production.sqlite3"
      end
    end
  end

  desc 'Open firewall port'
  task :open_firewall_port do
    on roles(:app) do
      execute 'ufw allow 3000/tcp || true'
      execute 'firewall-cmd --permanent --add-port=3000/tcp || true'
      execute 'firewall-cmd --reload || true'
    end
  end

  before :starting, :upload_config_files
  before :starting, :setup_environment
  before 'deploy:check:linked_files', 'deploy:setup_database'
  after :finishing, :open_firewall_port
end

# 资源预编译验证流程
after 'deploy:assets:precompile', 'assets:verify'
before 'deploy:restart', 'assets:verify'

after 'deploy:finishing', 'deploy:restart'
# Link puma restart task to deploy flow
after 'deploy:publishing', 'puma:restart'
