class FeeType < ApplicationRecord
  # Associations
  has_many :problem_types, dependent: :destroy
  

  # Validations
  validates :code, presence: true, uniqueness: true
  validates :title, presence: true
  validates :meeting_type, presence: true
  validates :active, inclusion: { in: [true, false] }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_meeting_type, ->(type) { where(meeting_type: type) }
  
  # Methods
  def display_name
    "#{code} - #{title}"
  end
  
  # ActiveAdmin configuration
  def self.ransackable_attributes(auth_object = nil)
    %w[id code title meeting_type active created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[problem_types fee_details]
  end
end