#!/bin/bash
set -e

# Display usage information
usage() {
  echo "Usage: $0 [COMMAND] [OPTIONS]"
  echo "Deploy and manage the sci2 application using Capistrano."
  echo ""
  echo "Commands:"
  echo "  deploy      Deploy the application (default)"
  echo "  setup       Set up the server for first deployment"
  echo "  rollback    Rollback to the previous version"
  echo "  status      Check the status of the application"
  echo "  logs        Check application logs"
  echo "  restart     Restart the application"
  echo "  diagnose    Run diagnostics on the deployment"
  echo "  assets      Force asset precompilation"
  echo ""
  echo "Options:"
  echo "  --staging     Deploy to staging environment (default)"
  echo "  --production  Deploy to production environment"
  echo "  --help        Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 deploy              # Deploy to staging environment"
  echo "  $0 setup --staging     # Set up staging environment"
  echo "  $0 status --production # Check status in production environment"
  echo "  $0 logs                # Check logs in staging environment"
  echo "  $0 restart             # Restart application in staging environment"
  echo "  $0 diagnose            # Run diagnostics on staging environment"
  echo "  $0 assets              # Force asset precompilation in staging environment"
}

# Parse command line arguments
COMMAND="deploy"  # Default command
ENVIRONMENT="staging"  # Default environment

# Parse the first argument as a command if it doesn't start with --
if [[ $# -gt 0 && ! "$1" == --* ]]; then
  COMMAND="$1"
  shift
fi

# Parse the remaining arguments as options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --staging)
      ENVIRONMENT="staging"
      shift
      ;;
    --production)
      ENVIRONMENT="production"
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Check if bundle is installed
if ! command -v bundle &> /dev/null; then
  echo "Error: bundle command not found. Please install bundler first."
  echo "Run: gem install bundler"
  exit 1
fi

# Execute the command
case "$COMMAND" in
  deploy)
    echo "=== Deploying sci2 to ${ENVIRONMENT} environment ==="
    bundle exec cap $ENVIRONMENT deploy
    ;;
  setup)
    echo "=== Setting up ${ENVIRONMENT} environment ==="
    bundle exec cap $ENVIRONMENT deploy:setup
    ;;
  rollback)
    echo "=== Rolling back to previous version in ${ENVIRONMENT} environment ==="
    bundle exec cap $ENVIRONMENT deploy:rollback
    ;;
  status)
    echo "=== Checking status in ${ENVIRONMENT} environment ==="
    bundle exec cap $ENVIRONMENT puma:status
    bundle exec cap $ENVIRONMENT deploy:check
    ;;
  logs)
    echo "=== Checking logs in ${ENVIRONMENT} environment ==="
    bundle exec cap $ENVIRONMENT deploy:log
    ;;
  restart)
    echo "=== Restarting application in ${ENVIRONMENT} environment ==="
    bundle exec cap $ENVIRONMENT puma:restart
    ;;
  diagnose)
    echo "=== Running diagnostics in ${ENVIRONMENT} environment ==="
    echo "1. Checking SSH connection..."
    bundle exec cap $ENVIRONMENT deploy:check
    echo "2. Checking application status..."
    bundle exec cap $ENVIRONMENT puma:status
    echo "3. Checking logs for errors..."
    bundle exec cap $ENVIRONMENT deploy:log
    ;;
  assets)
    echo "=== Forcing asset precompilation in ${ENVIRONMENT} environment ==="
    bundle exec cap $ENVIRONMENT deploy:assets:precompile
    bundle exec cap $ENVIRONMENT puma:restart
    ;;
  *)
    echo "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac

echo "=== Operation completed ==="