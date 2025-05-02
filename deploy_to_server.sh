#!/bin/bash
set -e

# Configuration
REMOTE_USER="root"
REMOTE_HOST="47.97.35.0"
REMOTE_DIR="/var/www/sci2"
LOCAL_DIR="."

# Check if SSH is available
if ! command -v ssh &> /dev/null; then
  echo "Error: ssh command not found"
  exit 1
fi

# Step 1: Prepare remote directory
echo "=== Preparing remote directory ==="
ssh ${REMOTE_USER}@${REMOTE_HOST} <<EOF
  mkdir -p ${REMOTE_DIR}
  rm -rf ${REMOTE_DIR}/*
EOF

# Step 2: Copy files (excluding .git, node_modules, etc.)
echo "=== Copying files to server ==="
rsync -avz --progress --exclude='.git/' --exclude='node_modules/' --exclude='tmp/' \
  ${LOCAL_DIR}/ ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/

# Step 3: Setup environment with Chinese mirrors
echo "=== Setting up environment with Chinese mirrors ==="
ssh ${REMOTE_USER}@${REMOTE_HOST} <<EOF
  # Change to project directory
  cd ${REMOTE_DIR}

  # Install RVM and Ruby
  if ! command -v rvm &> /dev/null; then
    echo "Installing RVM..."
    gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
    curl -sSL https://get.rvm.io | bash -s stable
    source /etc/profile.d/rvm.sh
  fi

  #echo "Installing Ruby 3.0.2..."
  #rvm install 3.0.2
  #rvm use 3.0.2 --default

  # Setup Ruby China gem source
  gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/
  
  # Setup Node.js npm registry
  if command -v npm &> /dev/null; then
    npm config set registry https://registry.npmmirror.com
  fi

  # Install bundler
  echo "Installing Bundler..."
  gem install bundler -v 2.5.23

  # Install dependencies
  echo "Installing Ruby dependencies..."
  bundle config mirror.https://rubygems.org https://gems.ruby-china.com
  bundle install --without production

  echo "Installing Node.js dependencies..."
  if [ -f "package.json" ]; then
    npm install
  fi

  # Setup database
  echo "Setting up database..."
  bundle exec rails db:create db:migrate

  # Start development server
  echo "Starting development server..."
  bundle exec rails server -d -b 0.0.0.0 -p 3000

  echo "Development server started on port 3000"
EOF

echo "=== Deployment completed ==="