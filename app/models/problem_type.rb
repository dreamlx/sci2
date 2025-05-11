class ProblemType < ApplicationRecord
  # Add other associations and validations here if needed

  def self.ransackable_attributes(auth_object = nil)
    %w[id name created_at updated_at] # Add other searchable attributes from your table
  end

  def self.ransackable_associations(auth_object = nil)
    [] # Add associations that should be searchable through ProblemType
  end
end
