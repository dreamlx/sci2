# 新生产服务器配置 - PostgreSQL直接安装
server 'tickmytime.com', user: 'deploy', roles: %w[app db web]

# 生产环境设置
set :stage, :production
set :rails_env, 'production'
set :branch, 'main'

# 使用Gitee仓库 (国内访问更快)
set :repo_url, 'https://gitee.com/dreamlx/sci2.git'
set :scm, :git
set :deploy_via, :remote_cache

# SSH配置 - 使用密钥认证
set :ssh_options, {
  keys: %w[~/.ssh/id_rsa],
  forward_agent: true,
  auth_methods: %w[publickey],
  verify_host_key: :never,
  user_known_hosts_file: '/dev/null',
  timeout: 300 # 增加超时时间
}

# RVM配置 - 使用系统RVM
set :default_env, {
  'PATH' => '/usr/local/rvm/gems/ruby-3.4.2/bin:/usr/local/rvm/gems/ruby-3.4.2@global/bin:/usr/local/rvm/rubies/ruby-3.4.2/bin:/usr/local/rvm/bin:$PATH',
  'GEM_HOME' => '/usr/local/rvm/gems/ruby-3.4.2',
  'GEM_PATH' => '/usr/local/rvm/gems/ruby-3.4.2:/usr/local/rvm/gems/ruby-3.4.2@global',
  'RUBY_VERSION' => 'ruby-3.4.2',
  'MY_RUBY_HOME' => '/usr/local/rvm/rubies/ruby-3.4.2',
  'rvm_path' => '/usr/local/rvm',
  'rvm_scripts_path' => '/usr/local/rvm/scripts'
}

# 确保使用正确的Ruby版本
set :ruby_version, '3.4.2'

# PostgreSQL配置
set :database_config, 'config/database.production.yml'

# 数据库凭据 (为了满足Capistrano要求)
set :database_username, 'sci2_prod'
set :database_password, 'your_secure_password'

# 环境变量
set :env_variables, {
  'RAILS_ENV' => 'production',
  'DATABASE_HOST' => 'localhost',
  'DATABASE_PORT' => '5432',
  'DATABASE_USERNAME' => 'sci2_prod',
  'DATABASE_PASSWORD' => 'your_secure_password',
  'RAILS_MAX_THREADS' => '20'
}

# 生产环境设置
set :deploy_to, '/opt/sci2'
set :keep_releases, 5
set :puma_workers, 4
set :puma_threads, [8, 32]

# Puma配置
set :puma_env, fetch(:rails_env)
set :puma_conf, "#{shared_path}/config/puma.rb"
set :puma_bind, 'tcp://0.0.0.0:3000'

# 解决root用户运行bundle的问题
set :bundle_binstubs, nil
set :bundle_gemfile, nil

# 部署后任务
after 'deploy:finished', :restart_puma do
  on roles(:app) do
    execute :sudo, :systemctl, :reload, :nginx
  end
end

# 修复bundle安装权限问题
namespace :deploy do
  desc 'Fix bundle permissions'
  task :fix_bundle_permissions do
    on roles(:app) do
      # 设置正确的权限
      execute :sudo, :chown, '-R', 'deploy:deploy', fetch(:deploy_to)
      execute :sudo, :chmod, '-R', '755', "#{fetch(:deploy_to)}/shared/bundle"
    end
  end

  after 'bundler:install', :fix_bundle_permissions
end
