# Define the server and user for production environment
server 'YOUR_PRODUCTION_IP', user: 'deploy', roles: %w{app db web}

# Production-specific settings
set :stage, :production
set :rails_env, 'production'
set :branch, 'main'  # Or your production branch name

# SSH options
set :ssh_options, {
  keys: %w(~/.ssh/id_rsa),
  forward_agent: true,
  auth_methods: %w(publickey)
}

# Puma configuration for production
set :puma_env, fetch(:rails_env)
set :puma_conf, "#{shared_path}/config/puma.rb"
set :puma_bind, "tcp://0.0.0.0:3000"

# Custom settings for production
set :docker_enabled, false  # Set to true if using Docker in production
set :deploy_to, "/opt/sci2/production"

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