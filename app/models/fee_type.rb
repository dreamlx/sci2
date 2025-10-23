class FeeType < ApplicationRecord
  has_many :problem_types, dependent: :destroy
  
  # Validations
  validates :name, presence: true
  validates :reimbursement_type_code, presence: true
  validates :meeting_type_code, presence: true
  validates :expense_type_code, presence: true
  validates :active, inclusion: { in: [true, false] }

  validates :expense_type_code, uniqueness: {
    scope: [:reimbursement_type_code, :meeting_type_code],
    message: "must be unique within the context of a reimbursement and meeting type"
  }

  # Scopes
  scope :active, -> { where(active: true) }
  
  # Methods

  # Alias for backward compatibility with tests that expect 'code' field
  def code
    expense_type_code
  end

  def code=(new_code)
    self.expense_type_code = new_code
  end

  # Alias for backward compatibility - some tests expect 'title' instead of 'name'
  def title
    name
  end

  def title=(new_title)
    self.name = new_title
  end

  def display_name
    "#{reimbursement_type_code}-#{meeting_type_code}-#{expense_type_code}: #{name}"
  end
  
  # ActiveAdmin configuration
  def self.ransackable_attributes(auth_object = nil)
    %w[id name active created_at updated_at reimbursement_type_code meeting_type_code expense_type_code meeting_name]
  end

  def self.ransackable_associations(auth_object = nil)
    # problem_types is no longer a direct association
    %w[problem_types]
  end
end