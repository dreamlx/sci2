#!/bin/bash
set -e

# Default configuration (same as deploy_to_server.sh)
REMOTE_USER="root"
REMOTE_HOST="47.97.35.0"
REMOTE_DIR="/var/www/sci2"
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

# Download database files from server's db/ directory
echo "=== Downloading database files from server's db/ directory ==="
rsync -avz --progress ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/db/*.sqlite3 ${LOCAL_DIR}/db/

# Download database files from server's root directory
echo "=== Downloading database files from server's root directory ==="
rsync -avz --progress ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/sci2_development* ${LOCAL_DIR}/

echo "=== Database fetch completed ==="

# Optional: Verify the downloaded files
echo "=== Verifying downloaded files ==="
if ls ${LOCAL_DIR}/db/*.sqlite3 1> /dev/null 2>&1; then
  echo "Successfully downloaded SQLite database files:"
  ls -la ${LOCAL_DIR}/db/*.sqlite3
else
  echo "Warning: No SQLite database files found in db/ directory after download"
fi

if ls ${LOCAL_DIR}/sci2_development* 1> /dev/null 2>&1; then
  echo "Successfully downloaded development database files:"
  ls -la ${LOCAL_DIR}/sci2_development*
else
  echo "Warning: No development database files found in root directory after download"
fi

echo "=== Database fetch from server completed successfully ==="
echo "You can now run your Rails application with the updated database"