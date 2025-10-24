namespace :fee_types do
  desc "Reset all fee type codes to '00'"
  task reset_codes: :environment do
    # Update all fee types with IDs 6-34 to have code '00'
    fee_types = FeeType.where(id: 6..34)

    fee_types.each do |fee_type|
      puts "Updating fee type ID #{fee_type.id} (#{fee_type.title}) with code '00'"
      fee_type.update(code: '00')
    end

    puts 'Fee type codes have been reset successfully.'
  end
end
