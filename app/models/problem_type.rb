class ProblemType < ApplicationRecord
  # Associations
  has_many :work_orders

  # Validations
  validates :code, presence: true, uniqueness: {
    scope: [:reimbursement_type_code, :meeting_type_code, :expense_type_code],
    message: "must be unique within the context of reimbursement, meeting, and expense type"
  }
  validates :title, presence: true
  validates :sop_description, presence: true
  validates :standard_handling, presence: true
  validates :active, inclusion: { in: [true, false] }
  validates :reimbursement_type_code, presence: true
  validates :meeting_type_code, presence: true
  validates :expense_type_code, presence: true

  # Scopes
  scope :active, -> { where(active: true) }

  # Methods
  def legacy_problem_code
    reimbursement = reimbursement_type_code.to_s
    meeting = meeting_type_code.to_s.rjust(2, '0')
    expense = expense_type_code.to_s.rjust(2, '0')
    issue = code.to_s
    
    result = "#{reimbursement}#{meeting}#{expense}#{issue}"
    
    # 同步更新数据库列
    if self[:legacy_problem_code] != result
      self[:legacy_problem_code] = result
    end
    
    result
  end

  def display_name
    "#{legacy_problem_code} - #{title}"
  end

  def full_description
    "#{display_name}\nSOP: #{sop_description}\nHandling: #{standard_handling}"
  end

  # ActiveAdmin configuration
  def self.ransackable_attributes(auth_object = nil)
    %w[id code title sop_description standard_handling active created_at updated_at
       reimbursement_type_code meeting_type_code expense_type_code legacy_problem_code]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[work_orders]
  end
end
