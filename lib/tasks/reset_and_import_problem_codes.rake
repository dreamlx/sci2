namespace :problem_codes do
  desc "Clear FeeType and ProblemType tables and reimport personal problem codes"
  task reset_and_import: :environment do
    ActiveRecord::Base.transaction do
      # Clear the tables in the correct order to respect foreign key constraints
      puts "Clearing dependent tables and problem codes..."
      
      # Check if WorkOrderProblem exists and has a reference to ProblemType
      if defined?(WorkOrderProblem) && WorkOrderProblem.column_names.include?('problem_type_id')
        puts "Clearing WorkOrderProblem records..."
        WorkOrderProblem.delete_all
      end
      
      # Check if any other models reference ProblemType or FeeType
      # For example, if there's a FeeDetailSelection model with fee_type_id
      if defined?(FeeDetailSelection) && FeeDetailSelection.column_names.include?('fee_type_id')
        puts "Clearing FeeDetailSelection records..."
        FeeDetailSelection.delete_all
      end
      
      # Now clear the main tables
      puts "Clearing ProblemType records..."
      ProblemType.delete_all
      
      puts "Clearing FeeType records..."
      FeeType.delete_all
      
      # Reset the auto-increment counters
      puts "Resetting auto-increment counters..."
      ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence WHERE name = 'problem_types'")
      ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence WHERE name = 'fee_types'")
      
      # Import personal problem codes
      csv_path = Rails.root.join('docs', 'user_data', '个人问题code.csv')
      puts "Importing personal problem codes from #{csv_path}..."
      
      result = ProblemCodeImportService.new(csv_path, '个人').import
      
      # Print summary
      puts "Import completed."
      puts "Fee Types: #{FeeType.count}"
      puts "Problem Types: #{ProblemType.count}"
    end
  end
end