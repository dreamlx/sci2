#!/usr/bin/env ruby
# Script to monitor for nil external_fee_id values in fee_details table
# Run with: rails runner db/scripts/monitor_nil_external_fee_ids.rb
#
# This script can be scheduled to run daily using a cron job:
# 0 3 * * * cd /path/to/app && RAILS_ENV=production rails runner db/scripts/monitor_nil_external_fee_ids.rb >> log/monitor_nil_external_fee_ids.log 2>&1

require 'logger'

# Initialize logger
log_file = ENV['LOG_FILE'] || "log/monitor_nil_external_fee_ids_#{Time.now.strftime('%Y%m%d')}.log"
logger = Logger.new(log_file)
logger.level = Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
end

# Set alert threshold (can be overridden with environment variable)
alert_threshold = (ENV['ALERT_THRESHOLD'] || 0).to_i

begin
  logger.info "Starting nil external_fee_id monitoring"
  
  # Find all records with nil external_fee_id
  nil_count = FeeDetail.where(external_fee_id: nil).count
  
  if nil_count > 0
    logger.warn "Found #{nil_count} fee_details with nil external_fee_id"
    
    # Get details of records with nil external_fee_id
    nil_records = FeeDetail.where(external_fee_id: nil)
                           .select(:id, :document_number, :fee_type, :amount, :updated_at, :created_at)
                           .order(created_at: :desc)
                           .limit(100) # Limit to avoid huge logs
    
    # Group by creation date to identify patterns
    by_date = nil_records.group_by { |r| r.created_at.to_date }
    
    logger.warn "Records by creation date:"
    by_date.each do |date, records|
      logger.warn "  - #{date}: #{records.size} records"
    end
    
    # Group by document_number to identify patterns
    by_document = nil_records.group_by(&:document_number)
    
    logger.warn "Top documents with nil external_fee_id:"
    by_document.sort_by { |_, records| -records.size }.take(10).each do |doc, records|
      logger.warn "  - Document #{doc}: #{records.size} records"
    end
    
    # Log individual records
    logger.warn "Sample records with nil external_fee_id:"
    nil_records.take(20).each do |record|
      logger.warn "  - ID: #{record.id}, Document: #{record.document_number}, Type: #{record.fee_type}, Amount: #{record.amount}, Created: #{record.created_at}, Updated: #{record.updated_at}"
    end
    
    if nil_records.size > 20
      logger.warn "  - ... and #{nil_count - 20} more records"
    end
    
    # Send alert if nil values exceed threshold
    if nil_count > alert_threshold
      logger.error "ALERT: Number of nil external_fee_id values (#{nil_count}) exceeds threshold (#{alert_threshold})"
      
      # Here you would integrate with your alert system
      # For example, sending an email or Slack notification
      # AlertService.send_alert("Nil external_fee_id Alert", {
      #   message: "Found #{nil_count} fee_details with nil external_fee_id",
      #   details: {
      #     by_date: by_date.transform_values(&:size),
      #     by_document: by_document.transform_values(&:size).sort_by { |_, v| -v }.take(10).to_h
      #   }
      # })
      
      puts "ALERT: Found #{nil_count} fee_details with nil external_fee_id. See log for details."
    end
  else
    logger.info "No fee_details with nil external_fee_id found"
  end
  
  # Also check for recently created records to ensure they have external_fee_id
  recent_period = ENV['RECENT_PERIOD'] ? ENV['RECENT_PERIOD'].to_i.days : 1.day
  recent_records = FeeDetail.where('created_at >= ?', Time.now - recent_period)
  recent_nil_records = recent_records.where(external_fee_id: nil)
  
  if recent_records.any?
    nil_percentage = (recent_nil_records.count.to_f / recent_records.count) * 100
    
    logger.info "Recent records check: #{recent_nil_records.count} out of #{recent_records.count} records created in the last #{recent_period / 1.day} day(s) have nil external_fee_id (#{nil_percentage.round(2)}%)"
    
    if recent_nil_records.any?
      logger.warn "Recent records with nil external_fee_id:"
      recent_nil_records.select(:id, :document_number, :fee_type, :amount, :created_at).each do |record|
        logger.warn "  - ID: #{record.id}, Document: #{record.document_number}, Type: #{record.fee_type}, Amount: #{record.amount}, Created: #{record.created_at}"
      end
      
      # Send alert for recent nil values
      logger.error "ALERT: #{nil_percentage.round(2)}% of records created in the last #{recent_period / 1.day} day(s) have nil external_fee_id"
      
      # Here you would integrate with your alert system
      # AlertService.send_alert("Recent Nil external_fee_id Alert", {
      #   message: "#{nil_percentage.round(2)}% of records created in the last #{recent_period / 1.day} day(s) have nil external_fee_id",
      #   details: recent_nil_records.map(&:id).join(", ")
      # })
      
      puts "ALERT: #{nil_percentage.round(2)}% of recent records have nil external_fee_id. See log for details."
    end
  else
    logger.info "No records created in the last #{recent_period / 1.day} day(s)"
  end
  
  logger.info "Monitoring completed successfully"
  
rescue => e
  logger.error "Error during monitoring: #{e.message}"
  logger.error e.backtrace.join("\n")
  puts "ERROR: Monitoring failed with error: #{e.message}. See log for details."
end