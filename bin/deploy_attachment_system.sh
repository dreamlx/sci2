#!/bin/bash

# SCI2 Attachment System Deployment Script
# This script automates the deployment of the attachment management system

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RAILS_ENV="${RAILS_ENV:-production}"
BACKUP_DIR="$PROJECT_ROOT/storage/backups/deployment"
LOG_FILE="$PROJECT_ROOT/log/deployment.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Colored output functions
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
    log "INFO: $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    log "SUCCESS: $1"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    log "WARNING: $1"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    log "ERROR: $1"
}

# Check if running as correct user
check_user() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    # Check Ruby version
    if ! command -v ruby &> /dev/null; then
        error "Ruby is not installed"
        exit 1
    fi
    
    ruby_version=$(ruby -v | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    info "Ruby version: $ruby_version"
    
    # Check Rails
    if ! command -v rails &> /dev/null; then
        error "Rails is not installed"
        exit 1
    fi
    
    rails_version=$(rails -v | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
    info "Rails version: $rails_version"
    
    # Check database connection
    if ! bundle exec rails runner "ActiveRecord::Base.connection" &> /dev/null; then
        error "Database connection failed"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

# Create backup
create_backup() {
    info "Creating deployment backup..."
    
    mkdir -p "$BACKUP_DIR"
    backup_timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file="$BACKUP_DIR/pre_deployment_$backup_timestamp.sql"
    
    # Database backup
    if command -v pg_dump &> /dev/null; then
        pg_dump "${DATABASE_URL:-sci2_$RAILS_ENV}" > "$backup_file"
        success "Database backup created: $backup_file"
    elif command -v mysqldump &> /dev/null; then
        mysqldump --single-transaction --routines --triggers sci2_$RAILS_ENV > "$backup_file"
        success "Database backup created: $backup_file"
    else
        warning "No database backup tool found, skipping database backup"
    fi
    
    # Code backup
    code_backup="$BACKUP_DIR/code_backup_$backup_timestamp.tar.gz"
    tar -czf "$code_backup" --exclude='storage' --exclude='log' --exclude='tmp' "$PROJECT_ROOT"
    success "Code backup created: $code_backup"
}

# Setup storage directories
setup_storage() {
    info "Setting up storage directories..."
    
    cd "$PROJECT_ROOT"
    
    if [[ -f "config/deploy/production_setup.rb" ]]; then
        bundle exec ruby config/deploy/production_setup.rb
        success "Storage directories configured"
    else
        # Fallback manual setup
        mkdir -p storage/attachments
        mkdir -p storage/backups/attachments
        mkdir -p log
        
        chmod 755 storage/attachments
        chmod 755 storage/backups
        chmod 755 log
        
        success "Storage directories created manually"
    fi
}

# Run database migrations
run_migrations() {
    info "Running database migrations..."
    
    cd "$PROJECT_ROOT"
    
    # Check pending migrations
    pending_migrations=$(bundle exec rake db:migrate:status RAILS_ENV=$RAILS_ENV | grep "^\s*down" | wc -l)
    
    if [[ $pending_migrations -gt 0 ]]; then
        info "Found $pending_migrations pending migrations"
        
        # Run migrations
        bundle exec rake db:migrate RAILS_ENV=$RAILS_ENV
        
        # Verify migrations
        if bundle exec rake db:migrate:status RAILS_ENV=$RAILS_ENV | grep -q "^\s*down"; then
            error "Some migrations failed to run"
            exit 1
        fi
        
        success "Database migrations completed"
    else
        success "No pending migrations found"
    fi
}

# Install dependencies
install_dependencies() {
    info "Installing dependencies..."
    
    cd "$PROJECT_ROOT"
    
    # Bundle install
    bundle install --deployment --without development test
    
    # Precompile assets
    bundle exec rake assets:precompile RAILS_ENV=$RAILS_ENV
    
    success "Dependencies installed and assets precompiled"
}

# Setup monitoring
setup_monitoring() {
    info "Setting up monitoring..."
    
    cd "$PROJECT_ROOT"
    
    # Create monitoring scripts if they don't exist
    if [[ ! -f "bin/monitor_storage.sh" ]]; then
        warning "Monitoring script not found, creating basic version..."
        
        cat > bin/monitor_storage.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."
export RAILS_ENV=production
bundle exec rake attachments:monitor_storage
EOF
        chmod +x bin/monitor_storage.sh
    fi
    
    if [[ ! -f "bin/backup_attachments.sh" ]]; then
        warning "Backup script not found, creating basic version..."
        
        cat > bin/backup_attachments.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/.."
export RAILS_ENV=production
bundle exec rake attachments:backup
bundle exec rake attachments:cleanup_backups
EOF
        chmod +x bin/backup_attachments.sh
    fi
    
    success "Monitoring scripts ready"
}

# Run tests
run_tests() {
    info "Running attachment system tests..."
    
    cd "$PROJECT_ROOT"
    
    # Run specific attachment tests
    test_files=(
        "spec/services/attachment_storage_service_spec.rb"
        "spec/services/attachment_upload_service_spec.rb"
        "spec/integration/attachment_upload_flow_spec.rb"
        "spec/integration/work_order_attachment_integration_spec.rb"
    )
    
    for test_file in "${test_files[@]}"; do
        if [[ -f "$test_file" ]]; then
            info "Running $test_file..."
            if ! bundle exec rspec "$test_file" --format documentation; then
                error "Test failed: $test_file"
                exit 1
            fi
        else
            warning "Test file not found: $test_file"
        fi
    done
    
    success "All attachment tests passed"
}

# Verify deployment
verify_deployment() {
    info "Verifying deployment..."
    
    cd "$PROJECT_ROOT"
    
    # Check if Rails can boot
    if ! timeout 30 bundle exec rails runner "puts 'Rails boot test successful'" RAILS_ENV=$RAILS_ENV; then
        error "Rails failed to boot"
        exit 1
    fi
    
    # Check database connectivity
    if ! bundle exec rails runner "ActiveRecord::Base.connection.execute('SELECT 1')" RAILS_ENV=$RAILS_ENV; then
        error "Database connectivity test failed"
        exit 1
    fi
    
    # Check attachment system
    if ! bundle exec rake attachments:storage_stats RAILS_ENV=$RAILS_ENV > /dev/null; then
        error "Attachment system verification failed"
        exit 1
    fi
    
    # Check file permissions
    if [[ ! -w "storage/attachments" ]]; then
        error "Storage directory is not writable"
        exit 1
    fi
    
    success "Deployment verification passed"
}

# Restart services
restart_services() {
    info "Restarting services..."
    
    # Try to restart common Rails application servers
    if systemctl is-active --quiet sci2; then
        sudo systemctl restart sci2
        success "Restarted sci2 service"
    elif systemctl is-active --quiet puma; then
        sudo systemctl restart puma
        success "Restarted puma service"
    elif [[ -f "tmp/pids/server.pid" ]]; then
        pid=$(cat tmp/pids/server.pid)
        if kill -0 "$pid" 2>/dev/null; then
            kill -USR2 "$pid"
            success "Sent restart signal to Rails server (PID: $pid)"
        fi
    else
        warning "No running Rails server found to restart"
    fi
    
    # Restart web server if available
    if systemctl is-active --quiet nginx; then
        sudo systemctl reload nginx
        success "Reloaded nginx"
    elif systemctl is-active --quiet apache2; then
        sudo systemctl reload apache2
        success "Reloaded apache2"
    fi
}

# Setup cron jobs
setup_cron() {
    info "Setting up cron jobs..."
    
    # Check if cron jobs already exist
    if crontab -l 2>/dev/null | grep -q "monitor_storage.sh"; then
        warning "Monitoring cron job already exists"
    else
        # Add monitoring job
        (crontab -l 2>/dev/null; echo "0 * * * * $PROJECT_ROOT/bin/monitor_storage.sh") | crontab -
        success "Added monitoring cron job"
    fi
    
    if crontab -l 2>/dev/null | grep -q "backup_attachments.sh"; then
        warning "Backup cron job already exists"
    else
        # Add backup job
        (crontab -l 2>/dev/null; echo "0 2 * * * $PROJECT_ROOT/bin/backup_attachments.sh") | crontab -
        success "Added backup cron job"
    fi
    
    if crontab -l 2>/dev/null | grep -q "attachments:cleanup_orphaned"; then
        warning "Cleanup cron job already exists"
    else
        # Add cleanup job
        (crontab -l 2>/dev/null; echo "0 3 * * 0 cd $PROJECT_ROOT && bundle exec rake attachments:cleanup_orphaned RAILS_ENV=$RAILS_ENV") | crontab -
        success "Added cleanup cron job"
    fi
}

# Generate deployment report
generate_report() {
    info "Generating deployment report..."
    
    report_file="$PROJECT_ROOT/log/deployment_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
SCI2 Attachment System Deployment Report
========================================

Deployment Date: $(date)
Rails Environment: $RAILS_ENV
Deployed By: $(whoami)
Server: $(hostname)

System Information:
- Ruby Version: $(ruby -v)
- Rails Version: $(rails -v)
- OS: $(uname -a)

Database Status:
$(bundle exec rake db:migrate:status RAILS_ENV=$RAILS_ENV | tail -10)

Storage Status:
$(bundle exec rake attachments:storage_stats RAILS_ENV=$RAILS_ENV 2>/dev/null || echo "Storage stats not available")

Cron Jobs:
$(crontab -l 2>/dev/null | grep -E "(monitor_storage|backup_attachments|cleanup_orphaned)" || echo "No attachment-related cron jobs found")

Deployment Log:
$(tail -50 "$LOG_FILE")
EOF
    
    success "Deployment report generated: $report_file"
}

# Main deployment function
main() {
    echo "🚀 SCI2 Attachment System Deployment"
    echo "===================================="
    echo
    
    # Initialize log file
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "Deployment started at $(date)" > "$LOG_FILE"
    
    # Run deployment steps
    check_user
    check_prerequisites
    create_backup
    setup_storage
    install_dependencies
    run_migrations
    setup_monitoring
    
    # Optional: Run tests (can be skipped with --skip-tests)
    if [[ "$1" != "--skip-tests" ]]; then
        run_tests
    else
        warning "Skipping tests as requested"
    fi
    
    verify_deployment
    restart_services
    setup_cron
    generate_report
    
    echo
    echo "🎉 Deployment completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Review the deployment report: $report_file"
    echo "2. Test the attachment functionality manually"
    echo "3. Monitor the application logs: tail -f $PROJECT_ROOT/log/production.log"
    echo "4. Check storage monitoring: bundle exec rake attachments:storage_stats RAILS_ENV=$RAILS_ENV"
    echo
    echo "For troubleshooting, check: $LOG_FILE"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--skip-tests] [--help]"
        echo
        echo "Options:"
        echo "  --skip-tests    Skip running tests during deployment"
        echo "  --help, -h      Show this help message"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac