# Define the server and user for production environment
vpn_ip = '100.98.75.43'
lan_ip = '192.168.9.209'

# To deploy via VPN, run: USE_VPN=true bundle exec cap production deploy
server_ip = ENV['USE_VPN'] ? vpn_ip : lan_ip
server server_ip, user: 'test', roles: %w{app db web}

# Production-specific settings
set :stage, :production
set :rails_env, 'development'
set :branch, 'main'  # Or your production branch name
# 使用 Gitee 仓库用于国内部署
set :repo_url, 'https://gitee.com/dreamlx/sci2.git'
set :scm, :git
set :deploy_via, :remote_cache
set :copy_strategy, nil

# SSH options - 使用密码认证而非密钥认证 (启用非交互式部署)
set :ssh_options, {
  password: '123456',
  auth_methods: %w(password),
  verify_host_key: :never,  # 跳过主机密钥验证
  user_known_hosts_file: '/dev/null',
  verbose: :debug,  # 添加详细日志
  non_interactive: true
}

# Puma configuration for production
set :puma_env, fetch(:rails_env)
set :puma_conf, "#{shared_path}/config/puma.rb"
set :puma_bind, "tcp://0.0.0.0:3000"

# Custom settings for production
set :docker_enabled, false  # Set to true if using Docker in production
set :deploy_to, "/opt/sci2"

# Database configuration for SQLite3
set :database_config, "#{shared_path}/config/database.yml"
# Database credentials - Using SQLite3, no credentials needed
set :database_username, ''
set :database_password, ''

# More conservative settings for production
set :keep_releases, 3
set :puma_workers, 4
set :puma_threads, [8, 32]

# Hook to run after deployment completes
after 'deploy:finished', :notify_slack do
  run_locally do
    execute :echo, "'Deployment to production completed successfully'"
  end
end