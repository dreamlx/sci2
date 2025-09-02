# Define the server and user for production environment
server '192.168.9.209', user: 'test', roles: %w{app db web}

# Production-specific settings
set :stage, :production
set :rails_env, 'production'
set :branch, 'main'  # Or your production branch name

# SSH options - 使用密码认证而非密钥认证
set :ssh_options, {
  password: '123456',
  auth_methods: %w(password),
  verify_host_key: :never,  # 跳过主机密钥验证
  user_known_hosts_file: '/dev/null',
  verbose: :debug  # 添加详细日志
}

# Puma configuration for production
set :puma_env, fetch(:rails_env)
set :puma_conf, "#{shared_path}/config/puma.rb"
set :puma_bind, "tcp://0.0.0.0:3000"

# Custom settings for production
set :docker_enabled, false  # Set to true if using Docker in production
set :deploy_to, "/opt/sci2"

# Database credentials - CHANGE THESE TO YOUR ACTUAL MYSQL CREDENTIALS
set :database_username, 'sci2'  # Change this to your MySQL username
set :database_password, 'sci2_password'  # Change this to your MySQL password

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