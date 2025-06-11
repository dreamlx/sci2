namespace :fee_types do
  desc "Update fee type codes with unique values based on IDs"
  task update_codes: :environment do
    # Update fee types with IDs 6-34 to have unique codes
    fee_types = FeeType.where(id: 6..34)
    
    fee_types.each do |fee_type|
      # Generate a unique code based on the ID
      new_code = "FT#{fee_type.id.to_s.rjust(3, '0')}"
      
      puts "Updating fee type ID #{fee_type.id} (#{fee_type.title}) with code '#{new_code}'"
      fee_type.update(code: new_code)
    end
    
    puts "Fee type codes have been updated successfully."
  end
end