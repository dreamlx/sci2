class ProblemDescription < ApplicationRecord
  belongs_to :problem_type
  has_many :work_orders # Assuming a problem description can be associated with multiple work orders

  validates :description, presence: true, uniqueness: { scope: :problem_type_id }
  # validates :active, inclusion: { in: [true, false] } # This is handled by `null: false` in DB

  scope :active, -> { where(active: true) }

  def self.ransackable_attributes(auth_object = nil)
    %w[id description problem_type_id created_at updated_at active]
  end

  def self.ransackable_associations(auth_object = nil)
    ["problem_type", "work_orders"] # Added work_orders
  end
end
