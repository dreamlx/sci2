#!/bin/bash

# Script to deploy the ActiveAdmin scopes patch to the server

# Set variables
SERVER="47.97.35.0"
USER="root"
APP_PATH="/var/www/sci2"

# Create the patch file locally
cat > active_admin_scopes_patch.rb << 'EOL'
# Patch for ActiveAdmin::Views::Scopes to fix the undefined method 'collection_before_scope' error
ActiveAdmin::Views::Scopes.class_eval do
  def collection_before_scope
    @collection_before_scope ||= collection
  end
end
EOL

# Copy the patch file to the server
scp active_admin_scopes_patch.rb ${USER}@${SERVER}:${APP_PATH}/config/initializers/

# SSH into the server and restart the application
ssh ${USER}@${SERVER} << 'ENDSSH'
cd /var/www/sci2
touch tmp/restart.txt
ENDSSH

# Clean up local file
rm active_admin_scopes_patch.rb

echo "Deployment completed. The patch has been applied to the server."