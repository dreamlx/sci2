#!/bin/bash
set -e

# Default configuration
REMOTE_USER="root"
REMOTE_HOST="47.97.35.0"
REMOTE_DIR="/var/www/sci2"
LOCAL_DIR="."
UPLOAD_DB=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --upload-db)
      UPLOAD_DB=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --upload-db    Upload local database to server (default: false)"
      echo "  -h, --help     Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use -h or --help to see available options"
      exit 1
      ;;
  esac
done

# Check if SSH is available
if ! command -v ssh &> /dev/null; then
  echo "Error: ssh command not found"
  exit 1
fi

# Step 1: Prepare remote directory
echo "=== Preparing remote directory ==="
ssh ${REMOTE_USER}@${REMOTE_HOST} <<EOF
  mkdir -p ${REMOTE_DIR}
  
  # Remove all files
  rm -rf ${REMOTE_DIR}/*
  
  # Create required directories
  mkdir -p ${REMOTE_DIR}/db
  mkdir -p ${REMOTE_DIR}/config
EOF

# Step 2: Initialize local database and run admin users seed
echo "=== Initializing local database ==="
bundle exec rails db:create db:migrate

echo "=== Running admin users seed locally ==="
bundle exec rails runner "load 'db/seeds/admin_users_seed.rb'"

# Step 3: Copy files (excluding .git, node_modules, databases, etc.)
echo "=== Copying files to server ==="
rsync -avz --progress --exclude='.git/' --exclude='node_modules/' --exclude='tmp/' \
  --exclude='db/*.sqlite3' --exclude='sci2_development*' --exclude='sci2_test*' \
  ${LOCAL_DIR}/ ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/
  
# Upload local SQLite database if requested
if [ "$UPLOAD_DB" = true ]; then
  echo "=== Uploading local database to server ==="
  # Upload database files from db/ directory
  rsync -avz --progress ${LOCAL_DIR}/db/*.sqlite3 ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/db/
  
  # Upload database files from root directory
  rsync -avz --progress ${LOCAL_DIR}/sci2_development* ${LOCAL_DIR}/sci2_test* ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/
  echo "=== Database upload completed ==="
else
  echo "=== Skipping database upload (use --upload-db to upload) ==="
fi

# Step 4: Setup environment with Chinese mirrors
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

  # Setup database (only run migrations, don't create or reset)
  echo "Setting up database (running migrations only)..."
  bundle exec rails db:migrate
  
  # Create sessions table for ActiveRecord session store
  echo "Creating sessions table..."
  bundle exec rails db:sessions:create

  # Start development server
  echo "Starting development server..."
  bundle exec rails server -d -b 0.0.0.0 -p 3000

  echo "Development server started on port 3000"
EOF

echo "=== Deployment completed ==="