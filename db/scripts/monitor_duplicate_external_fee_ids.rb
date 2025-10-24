#!/usr/bin/env ruby
# Script to monitor for duplicate external_fee_id values in fee_details table
# Run with: rails runner db/scripts/monitor_duplicate_external_fee_ids.rb
#
# This script can be scheduled to run daily using a cron job:
# 0 2 * * * cd /path/to/app && RAILS_ENV=production rails runner db/scripts/monitor_duplicate_external_fee_ids.rb >> log/monitor_duplicate_external_fee_ids.log 2>&1

require 'logger'

# Initialize logger
log_file = ENV['LOG_FILE'] || "log/monitor_duplicate_external_fee_ids_#{Time.now.strftime('%Y%m%d')}.log"
logger = Logger.new(log_file)
logger.level = Logger::INFO
logger.formatter = proc do |severity, datetime, _progname, msg|
  "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
end

# Set alert threshold (can be overridden with environment variable)
alert_threshold = (ENV['ALERT_THRESHOLD'] || 0).to_i

begin
  logger.info 'Starting duplicate external_fee_id monitoring'

  # Find all duplicate external_fee_id values
  duplicates = FeeDetail.select(:external_fee_id)
                        .group(:external_fee_id)
                        .having('COUNT(*) > 1')
                        .count

  if duplicates.any?
    logger.warn "Found #{duplicates.size} external_fee_id values with duplicates"

    # Log details of each duplicate
    duplicates.each do |external_id, count|
      logger.warn "  - external_fee_id '#{external_id}' has #{count} occurrences"

      # Get details of the duplicate records
      records = FeeDetail.where(external_fee_id: external_id)
                         .select(:id, :document_number, :fee_type, :amount, :updated_at)
                         .order(:id)

      records.each do |record|
        logger.warn "    - ID: #{record.id}, Document: #{record.document_number}, Type: #{record.fee_type}, Amount: #{record.amount}, Updated: #{record.updated_at}"
      end
    end

    # Send alert if duplicates exceed threshold
    if duplicates.size > alert_threshold
      logger.error "ALERT: Number of duplicate external_fee_id values (#{duplicates.size}) exceeds threshold (#{alert_threshold})"

      # Here you would integrate with your alert system
      # For example, sending an email or Slack notification
      # AlertService.send_alert("Duplicate external_fee_id Alert", {
      #   message: "Found #{duplicates.size} external_fee_id values with duplicates",
      #   details: duplicates.to_json
      # })

      puts "ALERT: Found #{duplicates.size} external_fee_id values with duplicates. See log for details."
    end
  else
    logger.info 'No duplicate external_fee_id values found'
  end

  # Also check for nil values
  nil_count = FeeDetail.where(external_fee_id: nil).count

  if nil_count > 0
    logger.warn "Found #{nil_count} fee_details with nil external_fee_id"

    # Log details of records with nil external_fee_id
    nil_records = FeeDetail.where(external_fee_id: nil)
                           .select(:id, :document_number, :fee_type, :amount, :updated_at)
                           .order(:id)
                           .limit(10) # Limit to avoid huge logs

    nil_records.each do |record|
      logger.warn "  - ID: #{record.id}, Document: #{record.document_number}, Type: #{record.fee_type}, Amount: #{record.amount}, Updated: #{record.updated_at}"
    end

    logger.warn "  - ... and #{nil_count - 10} more records" if nil_records.size > 10

    # Send alert for nil values
    logger.error "ALERT: Found #{nil_count} fee_details with nil external_fee_id"

    # Here you would integrate with your alert system
    # AlertService.send_alert("Nil external_fee_id Alert", {
    #   message: "Found #{nil_count} fee_details with nil external_fee_id",
    #   details: nil_records.map(&:id).join(", ")
    # })

    puts "ALERT: Found #{nil_count} fee_details with nil external_fee_id. See log for details."
  else
    logger.info 'No fee_details with nil external_fee_id found'
  end

  logger.info 'Monitoring completed successfully'
rescue StandardError => e
  logger.error "Error during monitoring: #{e.message}"
  logger.error e.backtrace.join("\n")
  puts "ERROR: Monitoring failed with error: #{e.message}. See log for details."
end
