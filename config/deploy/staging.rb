# Define the server and user for staging environment
server '47.97.35.0', user: 'root', roles: %w[app db web]

# Staging-specific settings
set :stage, :staging
set :rails_env, 'staging'
set :branch, 'main' # Or your staging branch name

# SSH options
set :ssh_options, {
  keys: %w[~/.ssh/id_rsa],
  forward_agent: true,
  auth_methods: %w[publickey]
}

# Puma configuration for staging
set :puma_env, fetch(:rails_env)
set :puma_conf, "#{shared_path}/config/puma.rb"
set :puma_bind, 'tcp://0.0.0.0:3000'

# Custom settings for staging
set :docker_enabled, false # Set to true if using Docker in staging
set :deploy_to, '/opt/sci2/staging'

# Hook to run after deployment completes
after 'deploy:finished', :notify_slack do
  run_locally do
    execute :echo, "'Deployment to staging completed successfully'"
  end
end
