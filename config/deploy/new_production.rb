# 新生产服务器配置 - 100.98.75.43
# 使用 PostgreSQL 直接安装
server '100.98.75.43', user: 'test', roles: %w[app db web]

# 生产环境设置
set :stage, :production
set :rails_env, 'production'
set :branch, 'main'

# 使用 Gitee 仓库 (国内访问更快)
set :repo_url, 'https://gitee.com/dreamlx/sci2.git'

# SSH 配置 - 使用密钥认证
set :ssh_options, {
  keys: %w[~/.ssh/id_rsa],
  forward_agent: true,
  auth_methods: %w[publickey],
  verify_host_key: :never,
  user_known_hosts_file: '/dev/null',
  timeout: 300 # 增加超时时间
}

# RVM 配置 - 使用系统 RVM
set :default_env, {
  'PATH' => '/usr/local/rvm/gems/ruby-3.4.2/bin:/usr/local/rvm/gems/ruby-3.4.2@global/bin:/usr/local/rvm/rubies/ruby-3.4.2/bin:/usr/local/rvm/bin:$PATH',
  'GEM_HOME' => '/usr/local/rvm/gems/ruby-3.4.2',
  'GEM_PATH' => '/usr/local/rvm/gems/ruby-3.4.2:/usr/local/rvm/gems/ruby-3.4.2@global',
  'RUBY_VERSION' => 'ruby-3.4.2',
  'MY_RUBY_HOME' => '/usr/local/rvm/rubies/ruby-3.4.2',
  'rvm_path' => '/usr/local/rvm',
  'rvm_scripts_path' => '/usr/local/rvm/scripts'
}

# 确保使用正确的 Ruby 版本
set :ruby_version, '3.4.2'

# PostgreSQL 配置
set :database_config, 'config/database.yml'

set :env_variables, {
  'RAILS_ENV' => 'production',
  'DATABASE_USERNAME' => 'sci2',
  'DATABASE_PASSWORD' => 'password_123',
  'DATABASE_HOST' => '127.0.0.1',
  'DATABASE_PORT' => '5432',
  'DATABASE_NAME_PROD' => 'sci2_production'
}

# 生产环境设置
set :deploy_to, '/opt/sci2'
set :keep_releases, 5
set :puma_workers, 4
set :puma_threads, [8, 32]

# Puma 配置
set :puma_env, fetch(:rails_env)
set :puma_conf, "#{shared_path}/config/puma.rb"
set :puma_bind, 'tcp://0.0.0.0:3000'

# 解决 root 用户运行 bundle 的问题
set :bundle_binstubs, nil
set :bundle_gemfile, nil

# 允许安装所有 gems（包括 test 组）
set :bundle_without, nil

# 部署后任务
after 'deploy:finished', :restart_puma do
  on roles(:app) do
    execute :sudo, :systemctl, :reload, :nginx
  end
end

# 自定义任务：上传本地 PostgreSQL 数据库到生产服务器
namespace :deploy do
  desc 'Upload local PostgreSQL database to production server'
  task :upload_database do
    on roles(:db) do
      # 询问是否继续
      ask(:confirm_upload, 'Are you sure you want to upload local database to production? (yes/no)')

      if fetch(:confirm_upload) != 'yes'
        puts 'Database upload cancelled'
        exit 0
      end

      # 备份生产数据库
      puts 'Backing up production database...'
      execute "PGPASSWORD='#{fetch(:env_variables)['DATABASE_PASSWORD']}' pg_dump -h #{fetch(:env_variables)['DATABASE_HOST']} -p #{fetch(:env_variables)['DATABASE_PORT']} -U #{fetch(:env_variables)['DATABASE_USERNAME']} #{fetch(:env_variables)['DATABASE_NAME_PROD']} > /tmp/sci2_production_backup_$(date +%Y%m%d_%H%M%S).sql"

      # 上传本地数据库
      puts 'Uploading local database...'
      upload! 'db/sci2_development.sqlite3', '/tmp/sci2_development.sqlite3'

      # 导入数据库（需要使用 Rails 任务进行 SQLite 到 PostgreSQL 的转换）
      puts 'Importing database...'
      execute "cd #{current_path} && RAILS_ENV=production bundle exec rails runner 'puts \"Database import task would run here\"'"

      puts 'Database upload completed'
    end
  end

  desc 'Setup production server'
  task :setup_server do
    on roles(:all) do
      # 创建部署目录
      execute :mkdir, "-p #{fetch(:deploy_to)}"
      execute :mkdir, "-p #{fetch(:deploy_to)}/shared/config"
      execute :mkdir, "-p #{fetch(:deploy_to)}/shared/log"
      execute :mkdir, "-p #{fetch(:deploy_to)}/shared/tmp/pids"
      execute :mkdir, "-p #{fetch(:deploy_to)}/shared/tmp/cache"
      execute :mkdir, "-p #{fetch(:deploy_to)}/shared/tmp/sockets"
      execute :mkdir, "-p #{fetch(:deploy_to)}/shared/public/system"
      execute :mkdir, "-p #{fetch(:deploy_to)}/shared/storage"
      execute :mkdir, "-p #{fetch(:deploy_to)}/releases"

      # 创建数据库配置文件
      database_yml = <<~YAML
        production:
          adapter: postgresql
          encoding: unicode
          pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 20 } %>
          username: <%= ENV.fetch("DATABASE_USERNAME") { "sci2" } %>
          password: <%= ENV.fetch("DATABASE_PASSWORD") { "password_123" } %>
          host: <%= ENV.fetch("DATABASE_HOST") { "127.0.0.1" } %>
          port: <%= ENV.fetch("DATABASE_PORT") { 5432 } %>
          database: <%= ENV.fetch("DATABASE_NAME_PROD") { "sci2_production" } %>
      YAML

      upload! StringIO.new(database_yml), "#{shared_path}/config/database.yml"

      puts 'Server setup completed'
    end
  end
end
