# lib/tasks/update_reimbursement_statuses.rake
namespace :reimbursements do
  desc "Update reimbursement statuses based on external status for existing data"
  task update_statuses: :environment do
    puts "Starting reimbursement status update..."

    # Find all reimbursements that are not manually overridden
    reimbursements = Reimbursement.where(manual_override: false)
    total_count = reimbursements.count
    updated_count = 0
    batch_size = 50 # Process in smaller batches to avoid long-running transactions

    puts "Found #{total_count} reimbursements to process in batches of #{batch_size}..."

    # Process in batches to avoid database locks
    reimbursements.find_in_batches(batch_size: batch_size).with_index do |batch, batch_index|
      updates_to_perform = []
      
      # First pass: identify what needs to be updated
      batch.each do |reimbursement|
        new_status = reimbursement.determine_internal_status_from_external(reimbursement.external_status)
        
        if new_status != reimbursement.status
          updates_to_perform << {
            id: reimbursement.id,
            invoice_number: reimbursement.invoice_number,
            old_status: reimbursement.status,
            new_status: new_status
          }
        end
      end

      # Second pass: perform batch update with retry logic
      if updates_to_perform.any?
        retry_count = 0
        max_retries = 3
        
        begin
          ActiveRecord::Base.transaction do
            updates_to_perform.each do |update_info|
              Reimbursement.where(id: update_info[:id]).update_all(status: update_info[:new_status])
              puts "Updated reimbursement #{update_info[:invoice_number]} from #{update_info[:old_status]} to #{update_info[:new_status]}"
              updated_count += 1
            end
          end
        rescue ActiveRecord::StatementInvalid => e
          if e.message.include?('database is locked') && retry_count < max_retries
            retry_count += 1
            puts "Database locked, retrying batch #{batch_index + 1} (attempt #{retry_count}/#{max_retries + 1})..."
            sleep(1 + retry_count) # Exponential backoff
            retry
          else
            puts "Failed to update batch #{batch_index + 1} after #{max_retries} retries: #{e.message}"
            raise e
          end
        end
      end

      # Progress logging
      processed = (batch_index + 1) * batch_size
      puts "Processed batch #{batch_index + 1}: #{[processed, total_count].min}/#{total_count} reimbursements..."
    end

    puts "Status update completed! Updated #{updated_count} out of #{total_count} reimbursements."
  end
end