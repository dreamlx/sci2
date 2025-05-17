class ProblemType < ApplicationRecord
  belongs_to :document_category, optional: true
  has_many :problem_descriptions, dependent: :destroy
  has_many :work_orders

  validates :name, presence: true, uniqueness: { scope: :document_category_id, message: "should be unique within a document category" }
  # validates :active, inclusion: { in: [true, false] } # This is handled by `null: false` in DB

  scope :active, -> { where(active: true) }

  def self.ransackable_attributes(auth_object = nil)
    %w[id name created_at updated_at active document_category_id]
  end

  def self.ransackable_associations(auth_object = nil)
    ["document_category", "problem_descriptions", "work_orders"]
  end
end
