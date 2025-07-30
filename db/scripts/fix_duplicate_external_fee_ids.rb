#!/usr/bin/env ruby
# Script to identify and fix duplicate external_fee_id values in fee_details table
# Run with: rails runner db/scripts/fix_duplicate_external_fee_ids.rb

require 'securerandom'

class FeeDetailDuplicateFixer
  def initialize
    @fixed_nil_count = 0
    @fixed_duplicate_count = 0
    @errors = []
  end

  def run
    ActiveRecord::Base.transaction do
      begin
        puts "Starting to fix fee_details with nil or duplicate external_fee_id values..."
        
        # Step 1: Fix nil external_fee_id values
        fix_nil_external_fee_ids
        
        # Step 2: Fix duplicate external_fee_id values
        fix_duplicate_external_fee_ids
        
        # Step 3: Verify no duplicates remain
        verify_no_duplicates_remain
        
        puts "\nSummary:"
        puts "  Fixed #{@fixed_nil_count} fee_details with nil external_fee_id"
        puts "  Fixed #{@fixed_duplicate_count} fee_details with duplicate external_fee_id"
        
        if @errors.any?
          puts "\nErrors encountered:"
          @errors.each { |error| puts "  - #{error}" }
          puts "\nRolling back changes due to errors."
          raise ActiveRecord::Rollback
        else
          puts "\nAll fee_details now have unique external_fee_id values."
        end
      rescue => e
        @errors << "Exception: #{e.message}"
        puts "\nError: #{e.message}"
        puts e.backtrace.join("\n")
        puts "\nRolling back changes due to exception."
        raise ActiveRecord::Rollback
      end
    end
  end

  private

  def fix_nil_external_fee_ids
    puts "\nStep 1: Fixing nil external_fee_id values..."
    
    # Find all fee_details with nil external_fee_id
    fee_details_with_nil_id = FeeDetail.where(external_fee_id: nil)
    count = fee_details_with_nil_id.count
    
    if count > 0
      puts "  Found #{count} fee_details with nil external_fee_id"
      
      fee_details_with_nil_id.each do |fee_detail|
        # Generate a unique ID with a prefix to identify script-generated IDs
        new_external_id = "GEN-#{SecureRandom.hex(8)}"
        
        begin
          fee_detail.update!(external_fee_id: new_external_id)
          @fixed_nil_count += 1
          puts "    Updated fee_detail ##{fee_detail.id} with external_fee_id: #{new_external_id}"
        rescue => e
          error_msg = "Failed to update fee_detail ##{fee_detail.id}: #{e.message}"
          @errors << error_msg
          puts "    ERROR: #{error_msg}"
        end
      end
      
      puts "  Fixed #{@fixed_nil_count} of #{count} fee_details with nil external_fee_id"
    else
      puts "  No fee_details with nil external_fee_id found"
    end
  end

  def fix_duplicate_external_fee_ids
    puts "\nStep 2: Fixing duplicate external_fee_id values..."
    
    # Find all duplicate external_fee_id values
    duplicates = FeeDetail.select(:external_fee_id)
                          .group(:external_fee_id)
                          .having("COUNT(*) > 1")
                          .count
    
    if duplicates.any?
      puts "  Found #{duplicates.size} external_fee_id values with duplicates"
      
      duplicates.each do |external_id, count|
        puts "    Processing external_fee_id: #{external_id} (#{count} occurrences)"
        
        # Get all records with this external_fee_id, ordered by updated_at DESC
        # This ensures we keep the most recently updated record unchanged
        records = FeeDetail.where(external_fee_id: external_id)
                           .order(updated_at: :desc)
                           .to_a
        
        # Skip the first record (most recently updated)
        records_to_update = records[1..-1]
        
        if records_to_update.any?
          puts "      Keeping record ##{records[0].id} unchanged (most recently updated)"
          puts "      Updating #{records_to_update.size} duplicate records with new IDs"
          
          records_to_update.each do |fee_detail|
            # Generate a new unique ID that includes the original ID for traceability
            new_external_id = "DEDUP-#{external_id}-#{fee_detail.id}-#{SecureRandom.hex(4)}"
            
            begin
              fee_detail.update!(external_fee_id: new_external_id)
              @fixed_duplicate_count += 1
              puts "        Updated fee_detail ##{fee_detail.id} with new external_fee_id: #{new_external_id}"
            rescue => e
              error_msg = "Failed to update fee_detail ##{fee_detail.id}: #{e.message}"
              @errors << error_msg
              puts "        ERROR: #{error_msg}"
            end
          end
        end
      end
      
      puts "  Fixed #{@fixed_duplicate_count} fee_details with duplicate external_fee_id"
    else
      puts "  No duplicate external_fee_id values found"
    end
  end

  def verify_no_duplicates_remain
    puts "\nStep 3: Verifying no duplicates remain..."
    
    # Check for any remaining duplicates
    remaining_duplicates = FeeDetail.select(:external_fee_id)
                                    .group(:external_fee_id)
                                    .having("COUNT(*) > 1")
                                    .count
    
    if remaining_duplicates.any?
      puts "  WARNING: #{remaining_duplicates.size} duplicate external_fee_id values still exist!"
      remaining_duplicates.each do |external_id, count|
        error_msg = "external_fee_id '#{external_id}' still has #{count} occurrences"
        @errors << error_msg
        puts "    - #{error_msg}"
      end
    else
      puts "  Verification successful: All fee_details now have unique external_fee_id values"
    end
    
    # Check for any remaining nil values
    nil_count = FeeDetail.where(external_fee_id: nil).count
    if nil_count > 0
      error_msg = "#{nil_count} fee_details still have nil external_fee_id"
      @errors << error_msg
      puts "  WARNING: #{error_msg}"
    end
  end
end

# Run the fixer
puts "=== Fee Detail Duplicate External ID Fixer ==="
puts "Started at: #{Time.now}"
puts "Database: #{ActiveRecord::Base.connection.current_database}"
puts "================================================"

fixer = FeeDetailDuplicateFixer.new
fixer.run

puts "\nCompleted at: #{Time.now}"
puts "================================================"