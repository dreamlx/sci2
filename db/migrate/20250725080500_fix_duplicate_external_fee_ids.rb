class FixDuplicateExternalFeeIds < ActiveRecord::Migration[6.1]
  def up
    # Check if external_fee_id column exists first
    unless column_exists?(:fee_details, :external_fee_id)
      puts 'external_fee_id column does not exist in fee_details table. Skipping migration.'
      return
    end

    # Find all duplicate external_fee_id values
    duplicates = execute(<<-SQL
      SELECT external_fee_id, COUNT(*) as count
      FROM fee_details
      GROUP BY external_fee_id
      HAVING COUNT(*) > 1
      ORDER BY count DESC
    SQL
                        ).to_a

    if duplicates.any?
      puts "Found #{duplicates.size} external_fee_id values with duplicates"

      duplicates.each do |row|
        external_id = row['external_fee_id']
        count = row['count'].to_i

        puts "  Processing external_fee_id: #{external_id} (#{count} occurrences)"

        # Get all records with this external_fee_id, ordered by updated_at DESC
        # This ensures we keep the most recently updated record unchanged
        records = execute(<<-SQL
          SELECT id, updated_at
          FROM fee_details
          WHERE external_fee_id = '#{external_id}'
          ORDER BY updated_at DESC
        SQL
                         ).to_a

        # Skip the first record (most recently updated)
        records_to_update = records[1..-1]

        next unless records_to_update.any?

        puts "    Keeping record ##{records[0]['id']} unchanged (most recently updated)"
        puts "    Updating #{records_to_update.size} duplicate records with new IDs"

        records_to_update.each do |record|
          id = record['id']
          # Generate a new unique ID that includes the original ID for traceability
          new_external_id = "DEDUP-#{external_id}-#{id}-#{SecureRandom.hex(4)}"

          execute <<-SQL
              UPDATE fee_details#{' '}
              SET external_fee_id = '#{new_external_id}',#{' '}
                  updated_at = NOW()#{' '}
              WHERE id = #{id}
          SQL

          puts "      Updated fee_detail ##{id} with new external_fee_id: #{new_external_id}"
        end
      end

      # Verify no duplicates remain
      remaining_duplicates = execute(<<-SQL
        SELECT COUNT(*) as count
        FROM (
          SELECT external_fee_id
          FROM fee_details
          GROUP BY external_fee_id
          HAVING COUNT(*) > 1
        ) as subquery
      SQL
                                    ).to_a.first['count'].to_i

      if remaining_duplicates > 0
        puts "WARNING: #{remaining_duplicates} duplicate external_fee_id values still exist!"
        puts 'Please run the fix_duplicate_external_fee_ids.rb script for more detailed handling.'
      else
        puts 'Successfully fixed all duplicate external_fee_id values'
      end
    else
      puts 'No duplicate external_fee_id values found'
    end
  end

  def down
    puts 'This migration cannot be reversed as it modifies data to ensure uniqueness.'
    puts 'If you need to restore the original state, please restore from a backup.'
  end
end
