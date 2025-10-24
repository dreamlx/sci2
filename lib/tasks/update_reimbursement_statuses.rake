# lib/tasks/update_reimbursement_statuses.rake
namespace :reimbursements do
  desc 'Update reimbursement statuses based on external status for existing data'
  task update_statuses: :environment do
    puts 'Starting reimbursement status update...'

    # Find all reimbursements that are not manually overridden
    reimbursements = Reimbursement.where(manual_override: false)
    total_count = reimbursements.count
    updated_count = 0

    puts "Found #{total_count} reimbursements to process..."

    reimbursements.find_each.with_index do |reimbursement, index|
      # Calculate new status based on external status
      new_status = reimbursement.determine_internal_status_from_external(reimbursement.external_status)

      # Only update if status has changed
      if new_status != reimbursement.status
        reimbursement.update!(status: new_status)
        updated_count += 1
        puts "Updated reimbursement #{reimbursement.invoice_number} from #{reimbursement.status} to #{new_status}"
      end

      # Progress logging
      puts "Processed #{index + 1}/#{total_count} reimbursements..." if (index + 1) % 100 == 0
    end

    puts "Status update completed! Updated #{updated_count} out of #{total_count} reimbursements."
  end
end
