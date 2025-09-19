#!/bin/bash
set -e

# Default configuration for VPN environment (using Capistrano paths)
REMOTE_USER="test"
REMOTE_HOST="100.98.75.43"
REMOTE_DIR="/opt/sci2"
LOCAL_DIR="."

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
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

# Check if rsync is available
if ! command -v rsync &> /dev/null; then
  echo "Error: rsync command not found"
  exit 1
fi

echo "=== Fetching database from server ==="

# Create backup of local database before replacing
echo "=== Creating backup of local database ==="
if [ -d "${LOCAL_DIR}/db" ]; then
  mkdir -p "${LOCAL_DIR}/db_backup"
  cp -r "${LOCAL_DIR}/db"/*.sqlite3 "${LOCAL_DIR}/db_backup/" 2>/dev/null || true
fi

if ls ${LOCAL_DIR}/sci2_development* 1> /dev/null 2>&1; then
  mkdir -p "${LOCAL_DIR}/db_backup"
  cp ${LOCAL_DIR}/sci2_development* "${LOCAL_DIR}/db_backup/" 2>/dev/null || true
fi

echo "Local database backup created in db_backup/ directory"

# Download production database from shared directory (Capistrano structure)
echo "=== Downloading production database from shared directory ==="
rsync -avz --progress ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/shared/db/sci2_production.sqlite3 ${LOCAL_DIR}/

# Rename to development database for local use
echo "=== Setting up local development database ==="
if [ -f "${LOCAL_DIR}/sci2_production.sqlite3" ]; then
  cp "${LOCAL_DIR}/sci2_production.sqlite3" "${LOCAL_DIR}/sci2_development.sqlite3"
  echo "Production database copied to sci2_development.sqlite3 for local development"
fi

echo "=== Database fetch completed ==="

# Optional: Verify the downloaded files
echo "=== Verifying downloaded files ==="
if [ -f "${LOCAL_DIR}/sci2_production.sqlite3" ]; then
  echo "Successfully downloaded production database:"
  ls -la ${LOCAL_DIR}/sci2_production.sqlite3
else
  echo "Warning: Production database file not found after download"
fi

if [ -f "${LOCAL_DIR}/sci2_development.sqlite3" ]; then
  echo "Successfully created development database:"
  ls -la ${LOCAL_DIR}/sci2_development.sqlite3
else
  echo "Warning: Development database file not created"
fi

echo "=== Database fetch from server completed successfully ==="
echo "You can now run your Rails application with the updated database"