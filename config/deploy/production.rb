# 新生产服务器配置 - PostgreSQL直接安装
server 'tickmytime.com', user: 'deploy', roles: %w[app db web]

# 生产环境设置
set :stage, :production
set :rails_env, 'production'
set :branch, 'main'

# 使用Gitee仓库 (国内访问更快)
set :repo_url, 'https://gitee.com/dreamlx/sci2.git'

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

# Puma配置
set :puma_env, fetch(:rails_env)
set :puma_conf, "#{shared_path}/config/puma.rb"
set :puma_bind, 'tcp://0.0.0.0:3000'

# 解决root用户运行bundle的问题
set :bundle_binstubs, nil
set :bundle_gemfile, nil

# 允许安装所有gems（包括test组）
set :bundle_without, nil

# 部署后任务
after 'deploy:finished', :restart_puma do
  on roles(:app) do
    execute :sudo, :systemctl, :reload, :nginx
  end
end
