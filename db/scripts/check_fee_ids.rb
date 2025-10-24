# Script to check external_fee_id values in the database
# Run with: rails runner db/scripts/check_fee_ids.rb

puts 'Checking external_fee_id values in fee_details table...'

# Check for null or empty external_fee_id values
null_count = FeeDetail.where(external_fee_id: nil).count
empty_count = FeeDetail.where(external_fee_id: '').count
puts "Records with null external_fee_id: #{null_count}"
puts "Records with empty external_fee_id: #{empty_count}"

# Check for duplicate external_fee_id values
duplicates = FeeDetail.group(:external_fee_id).having('COUNT(*) > 1').count
puts "\nDuplicate external_fee_id values:"
if duplicates.empty?
  puts 'No duplicates found.'
else
  puts "Found #{duplicates.size} unique external_fee_id values that appear in multiple records:"
  duplicates.each do |fee_id, count|
    next if fee_id.nil? # Skip nil values

    puts "  #{fee_id}: appears #{count} times"

    # Show details of the first few duplicates
    if count <= 5
      FeeDetail.where(external_fee_id: fee_id).each do |fd|
        puts "    ID: #{fd.id}, Document: #{fd.document_number}, Amount: #{fd.amount}, Date: #{fd.fee_date}"
      end
    else
      puts '    (Too many to display details)'
    end
  end
end

# Check for truncation issues (looking for IDs ending with 0000)
truncated_pattern = FeeDetail.where("external_fee_id LIKE '%0000'").count
puts "\nRecords with external_fee_id ending in '0000': #{truncated_pattern}"

# Sample some of these records
puts "\nSample records with external_fee_id ending in '0000':"
FeeDetail.where("external_fee_id LIKE '%0000'").limit(5).each do |fd|
  puts "  ID: #{fd.id}, external_fee_id: #{fd.external_fee_id}, Document: #{fd.document_number}"
end

# Check the length distribution of external_fee_id values
puts "\nLength distribution of external_fee_id values:"
length_counts = {}
FeeDetail.where.not(external_fee_id: nil).find_each do |fd|
  length = fd.external_fee_id.to_s.length
  length_counts[length] ||= 0
  length_counts[length] += 1
end

length_counts.sort.each do |length, count|
  puts "  Length #{length}: #{count} records"
end

# Check if there are any non-numeric external_fee_id values
# Using a different approach since SQLite doesn't support regex
non_numeric = 0
FeeDetail.where.not(external_fee_id: nil).where.not(external_fee_id: '').limit(1000).each do |fd|
  non_numeric += 1 unless fd.external_fee_id.to_s =~ /^\d+$/
end
puts "\nRecords with non-numeric external_fee_id (from sample of 1000): #{non_numeric}"

puts "\nAnalysis complete."
