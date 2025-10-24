# config valid for current version and patch releases of Capistrano
lock '~> 3.19.2'

set :application, 'sci2'
set :repo_url, 'https://github.com/dreamlx/sci2.git' # 使用HTTPS URL而不是SSH URL

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp
set :branch, 'main' # 根据需要更新您的主分支名称

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, '/opt/sci2'

# Default value for :format is :airbrussh
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
set :pty, true

# Default value for :linked_files is []
append :linked_files, 'config/database.yml', 'config/master.key'

# Default value for linked_dirs is []
append :linked_dirs, 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'public/system', 'storage'

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

# Bundler options
set :bundle_flags, '--quiet'
set :bundle_jobs, 4
set :bundle_without, %w[test].join(' ')
set :bundle_path, -> { shared_path.join('bundle') }
set :bundle_binstubs, -> { shared_path.join('bin') }
set :bundle_roles, :all
set :bundle_bins, %w[gem rake rails]
set :bundle_env_variables, { BUNDLE_IGNORE_CONFIG: '1' }

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

# Custom tasks
namespace :deploy do
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # 使用直接部署方式重启应用，而不是使用puma systemd服务
      if fetch(:docker_enabled, false)
        invoke! 'puma:restart'
      else
        invoke! 'direct_deploy:restart'
      end
    end
  end

  desc 'Upload database.yml and master.key files'
  task :upload_config_files do
    on roles(:app) do
      upload! 'config/database.yml', "#{shared_path}/config/database.yml"
      upload! 'config/master.key', "#{shared_path}/config/master.key"
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
  after :finishing, :open_firewall_port
end

# 根据部署方式选择重启方法
namespace :custom do
  desc '根据部署方式选择合适的重启方法'
  task :restart_app do
    on roles(:app) do
      if fetch(:docker_enabled, false)
        info '使用Docker方式重启应用'
        # 这里不调用任何重启命令，因为Docker已禁用
      else
        info '使用直接部署方式重启应用'
        invoke! 'direct_deploy:restart'
      end
    end
  end
end

# 添加自定义重启任务到部署流程
after 'deploy:finishing', 'custom:restart_app'

# 禁用Puma Capistrano任务，避免systemd相关错误
Rake::Task['puma:restart'].clear_actions if Rake::Task.task_defined?('puma:restart')
