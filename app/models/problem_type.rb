class ProblemType < ApplicationRecord
  # Associations
  belongs_to :fee_type
  has_many :work_orders

  # Validations
  validates :issue_code, presence: true, uniqueness: {
    scope: :fee_type_id,
    message: "must be unique within a fee_type"
  }
  validates :title, presence: true
  validates :sop_description, presence: true
  validates :standard_handling, presence: true
  validates :active, inclusion: { in: [true, false] }

  # Scopes
  scope :active, -> { where(active: true) }

  # Methods
  def legacy_problem_code
    # 通过 fee_type 关联获取 code，确保 fee_type 存在
    return nil unless fee_type

    reimbursement = fee_type.reimbursement_type_code.to_s
    meeting = fee_type.meeting_type_code.to_s.rjust(2, '0')
    expense = fee_type.expense_type_code.to_s.rjust(2, '0')
    issue = issue_code.to_s
    
    result = "#{reimbursement}#{meeting}#{expense}#{issue}"
    
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
    # ** 更新以包含新字段并移除旧字段 **
    %w[id issue_code title sop_description standard_handling active created_at updated_at fee_type_id legacy_problem_code]
  end

  def self.ransackable_associations(auth_object = nil)
    # ** 添加 fee_type 关联 **
    %w[work_orders fee_type]
  end
end
