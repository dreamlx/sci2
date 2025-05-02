#!/bin/bash
set -e

# Configuration
REMOTE_USER="root"
REMOTE_HOST="47.97.35.0"

echo "=== Installing dependencies on ${REMOTE_USER}@${REMOTE_HOST} ==="

# Step 1: Update package lists and install basic dependencies
echo "Step 1: Updating package lists and installing basic dependencies..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "
  # Remove problematic repositories
  rm -f /etc/apt/sources.list.d/docker.list
  rm -f /etc/apt/sources.list.d/brightbox-ubuntu-ruby-ng-*.list
  
  # Update package lists
  apt-get update
  
  # Install required packages
  apt-get install -y build-essential libsqlite3-dev nodejs npm curl gnupg2
"

# Step 2: Install Ruby 3.4.2 using RVM
echo "Step 2: Installing Ruby 3.4.2 using RVM..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "
  # Check if RVM is installed
  if ! command -v rvm &> /dev/null; then
    echo 'RVM not found. Installing RVM...'
    curl -sSL https://get.rvm.io | bash -s stable
    source /etc/profile.d/rvm.sh
  else
    echo 'RVM is already installed.'
    source /usr/local/rvm/scripts/rvm
  fi
  
  # Install Ruby 3.4.2
  rvm install 3.4.2
  rvm use 3.4.2 --default
  
  # Install bundler
  gem install bundler
"

# Step 3: Install Node.js and Yarn
echo "Step 3: Installing Node.js and Yarn..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "
  # Check if Node.js is installed
  if ! command -v node &> /dev/null; then
    echo 'Node.js not found. Installing Node.js...'
    curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
    apt-get install -y nodejs
  else
    echo 'Node.js is already installed.'
  fi
  
  # Check if Yarn is installed
  if ! command -v yarn &> /dev/null; then
    echo 'Yarn not found. Installing Yarn...'
    npm install -g yarn
  else
    echo 'Yarn is already installed.'
  fi
"

echo "=== Dependencies installation completed successfully! ==="
echo "You can now deploy the application using ./deploy_simple.sh"