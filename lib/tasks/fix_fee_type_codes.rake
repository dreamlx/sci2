namespace :fee_types do
  desc 'Fix fee type codes from CSV data'
  task fix_codes: :environment do
    require 'csv'

    # Path to the CSV file
    csv_path = Rails.root.join('docs', 'user_data', '个人问题code.csv')

    if File.exist?(csv_path)
      puts "Reading CSV file from #{csv_path}..."

      # Read file content and remove BOM if present
      content = File.read(csv_path)
      content = content.sub("\xEF\xBB\xBF", '') if content.start_with?("\xEF\xBB\xBF")

      # Create a hash to store fee type titles and their corresponding codes
      fee_type_mapping = {}

      # Parse CSV and build the mapping
      CSV.parse(content, headers: true, encoding: 'UTF-8') do |row|
        exp_code = row['Exp. Code']&.strip
        fee_type_title = row['费用类型']&.strip

        fee_type_mapping[fee_type_title] = exp_code if exp_code.present? && fee_type_title.present?
      end

      # Update fee types based on the mapping
      fee_type_mapping.each do |title, code|
        fee_type = FeeType.find_by(title: title)

        if fee_type
          puts "Updating fee type '#{title}' with code '#{code}'"
          fee_type.update(code: code)
        else
          puts "Fee type with title '#{title}' not found"
        end
      end

      puts 'Fee type codes have been updated successfully.'
    else
      puts "CSV file not found at #{csv_path}"
    end
  end
end
