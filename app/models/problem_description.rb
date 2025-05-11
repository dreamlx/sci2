class ProblemDescription < ApplicationRecord
  belongs_to :problem_type
  # Add other associations and validations here if needed

  def self.ransackable_attributes(auth_object = nil)
    %w[id name description problem_type_id created_at updated_at] # Assuming 'description' is a field, add others as needed
  end

  def self.ransackable_associations(auth_object = nil)
    %w[problem_type] # Allow searching through problem_type from problem_description
  end
end
