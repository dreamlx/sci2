namespace :sci2 do
  desc "Fix fee_detail_selections by removing verification_status values"
  task fix_fee_detail_selections: :environment do
    puts "Starting to fix fee_detail_selections..."
    
    # This task is a safety measure to ensure data consistency
    # It should be run before applying the migration to remove the verification_status column
    
    # Count total records
    total_count = FeeDetailSelection.count
    puts "Total fee_detail_selections records: #{total_count}"
    
    # Get all fee details with their current verification status
    fee_details_with_status = {}
    
    # First, collect all fee detail statuses from FeeDetailSelections
    FeeDetailSelection.find_each do |selection|
      fee_detail_id = selection.fee_detail_id
      
      # Skip if fee detail doesn't exist
      next unless FeeDetail.exists?(id: fee_detail_id)
      
      # Store the status if it's verified (highest priority)
      if selection.respond_to?(:verification_status) && selection.verification_status == 'verified'
        fee_details_with_status[fee_detail_id] = 'verified'
      # Store problematic status if not already verified
      elsif selection.respond_to?(:verification_status) && 
            selection.verification_status == 'problematic' && 
            fee_details_with_status[fee_detail_id] != 'verified'
        fee_details_with_status[fee_detail_id] = 'problematic'
      # Store pending status if not already verified or problematic
      elsif selection.respond_to?(:verification_status) && 
            selection.verification_status == 'pending' && 
            !fee_details_with_status.key?(fee_detail_id)
        fee_details_with_status[fee_detail_id] = 'pending'
      end
    end
    
    # Now update the FeeDetail records with the collected statuses
    updated_count = 0
    fee_details_with_status.each do |fee_detail_id, status|
      fee_detail = FeeDetail.find_by(id: fee_detail_id)
      next unless fee_detail
      
      if fee_detail.verification_status != status
        fee_detail.update_column(:verification_status, status)
        updated_count += 1
      end
    end
    
    puts "Updated #{updated_count} fee details with statuses from fee_detail_selections"
    puts "Task completed successfully!"
  end
end