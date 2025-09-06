FactoryBot.define do
  factory :problem_type do
    sequence(:code) { |n| n.to_s.rjust(2, '0') } # This is the issue_code now
    sequence(:title) { |n| "问题类型#{n}" }
    sop_description { "标准操作描述..." }
    standard_handling { "标准处理方式..." }
    reimbursement_type_code { ['EN', 'MN'].sample }
    sequence(:meeting_type_code) { |n| n.to_s.rjust(2, '0') }
    sequence(:expense_type_code) { |n| n.to_s.rjust(2, '0') }
    sequence(:legacy_problem_code) { |n| "#{reimbursement_type_code}#{meeting_type_code}#{expense_type_code}#{code}" }
    active { true }
  end
end
