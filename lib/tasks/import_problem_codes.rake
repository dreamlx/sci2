namespace :problem_codes do
  desc "Import problem codes from CSV files"
  task import: :environment do
    # Import personal problem codes
    personal_csv_path = Rails.root.join('docs', 'user_data', '个人问题code.csv')
    if File.exist?(personal_csv_path)
      puts "Importing personal problem codes from #{personal_csv_path}..."
      result = ProblemCodeImportService.new(personal_csv_path).import
      
      if result[:success]
        puts "Personal problem codes imported successfully:"
        puts "  - #{result[:imported_fee_types]} fee types created"
        puts "  - #{result[:updated_fee_types]} fee types updated"
        puts "  - #{result[:imported_problem_types]} problem types created"
        puts "  - #{result[:updated_problem_types]} problem types updated"
      else
        puts "Error importing personal problem codes: #{result[:error]}"
      end
    else
      puts "Warning: Personal problem codes CSV file not found at #{personal_csv_path}"
    end
    
    # Import academic problem codes
    academic_csv_path = Rails.root.join('docs', 'user_data', '学术问题code.csv')
    if File.exist?(academic_csv_path)
      puts "Importing academic problem codes from #{academic_csv_path}..."
      result = ProblemCodeImportService.new(academic_csv_path).import
      
      if result[:success]
        puts "Academic problem codes imported successfully:"
        puts "  - #{result[:imported_fee_types]} fee types created"
        puts "  - #{result[:updated_fee_types]} fee types updated"
        puts "  - #{result[:imported_problem_types]} problem types created"
        puts "  - #{result[:updated_problem_types]} problem types updated"
      else
        puts "Error importing academic problem codes: #{result[:error]}"
      end
    else
      puts "Warning: Academic problem codes CSV file not found at #{academic_csv_path}"
    end
    
    # Print summary
    puts "\nImport Summary:"
    puts "Fee Types: #{FeeType.count}"
    puts "Problem Types: #{ProblemType.count}"
  end
  
  desc "Migrate existing problem codes to new structure"
  task migrate: :environment do
    puts "Migrating existing problem codes to new structure..."
    ProblemCodeMigrationService.migrate_to_new_structure
    puts "Migration completed successfully."
    
    # Print summary
    puts "\nMigration Summary:"
    puts "Fee Types: #{FeeType.count}"
    puts "Problem Types: #{ProblemType.count}"
  end
  
  desc "Reset and initialize problem codes"
  task reset: :environment do
    puts "Resetting problem codes..."
    
    ActiveRecord::Base.transaction do
      # Clear existing data
      ProblemType.delete_all
      FeeType.delete_all
      
      # Run import
      Rake::Task["problem_codes:import"].invoke
    end
    
    puts "Problem codes reset and initialized successfully."
  end
end