class ProblemType < ApplicationRecord
  # Associations
  belongs_to :fee_type, optional: true
  has_many :work_orders
  
  # Validations
  validates :code, presence: true, uniqueness: true
  validates :title, presence: true
  validates :title, presence: true
  validates :sop_description, presence: true
  validates :standard_handling, presence: true
  validates :active, inclusion: { in: [true, false] }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_fee_type, ->(fee_type_id) { where(fee_type_id: fee_type_id) }
  
  # Methods
  def display_name
    fee_type_prefix = fee_type.present? ? "#{fee_type.code}:" : ""
    "#{fee_type_prefix}#{code} - #{title}"
  end
  
  def full_description
    fee_type_info = fee_type.present? ? "#{fee_type.display_name} > " : ""
    "#{fee_type_info}#{display_name}\n    #{sop_description}\n    #{standard_handling}"
  end
  
  # ActiveAdmin configuration
  def self.ransackable_attributes(auth_object = nil)
    %w[id code title sop_description standard_handling fee_type_id active created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[fee_type work_orders]
  end
end
