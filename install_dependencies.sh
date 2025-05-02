#!/bin/bash
set -e

echo "=== Installing dependencies for sci2 deployment ==="

# Check and install system dependencies
echo "Step 1: Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  libsqlite3-dev \
  nodejs \
  npm \
  curl \
  gnupg2 \
  git

# Install RVM and Ruby
echo "Step 2: Installing RVM and Ruby..."
if ! command -v rvm &> /dev/null; then
  curl -sSL https://get.rvm.io | bash -s stable
  source ~/.rvm/scripts/rvm
fi

rvm install 3.4.2
rvm use 3.4.2 --default

# Install Bundler
echo "Step 3: Installing Bundler..."
gem install bundler

# Install Node.js and Yarn
echo "Step 4: Installing Node.js and Yarn..."
if ! command -v node &> /dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

if ! command -v yarn &> /dev/null; then
  sudo npm install -g yarn
fi

# Install Capistrano and dependencies
echo "Step 5: Installing Capistrano and dependencies..."
bundle install

echo "=== Dependencies installation completed successfully! ==="
echo "You can now deploy the application using:"
echo "  ./deploy_with_capistrano.sh setup --staging"