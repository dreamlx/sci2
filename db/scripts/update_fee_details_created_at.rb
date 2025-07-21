# Script to update fee_details created_at from today to yesterday
# Run this in the Rails console

today = Date.today.beginning_of_day
yesterday = (Date.today - 1.day).beginning_of_day

# Find today's records and update them to yesterday
today_records = FeeDetail.where("created_at >= ?", today)
count = today_records.count
puts "Found #{count} fee_details records created today"

# Update all records in a single operation
today_records.update_all(created_at: yesterday + 12.hours)
puts "Updated #{count} records to have created_at set to yesterday"

# Verify the update
remaining_today = FeeDetail.where("created_at >= ?", today).count
puts "Remaining records with today's date: #{remaining_today}"