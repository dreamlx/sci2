# lib/tasks/data_migration/populate_fee_type_id_for_problem_types.rake
namespace :data_migration do
  desc "Populates fee_type_id for existing ProblemType records based on the old _code columns."
  task :populate_fee_type_id_for_problem_types => :environment do

    # We need to define a temporary model within the migration to ensure we can
    # safely access the old columns, even after the main model has been updated.
    class LegacyProblemType < ApplicationRecord
      self.table_name = :problem_types
    end

    puts "Starting data migration: Populating fee_type_id for problem_types..."
    
    # We iterate over all problem_types that do not yet have a fee_type_id
    LegacyProblemType.where(fee_type_id: nil).find_each do |pt|
      # Find the corresponding FeeType using the (now removed from the main model) _code fields.
      fee_type = FeeType.find_by(
        reimbursement_type_code: pt.reimbursement_type_code,
        meeting_type_code: pt.meeting_type_code,
        expense_type_code: pt.expense_type_code
      )
      
      if fee_type
        # Using update_column to bypass validations and callbacks for performance.
        pt.update_column(:fee_type_id, fee_type.id)
        print "."
      else
        print "F"
        puts "\nWARNING: Could not find a matching FeeType for ProblemType ##{pt.id}."
      end
    end

    puts "\n\nData migration for populating fee_type_id on problem_types completed."
  end
end