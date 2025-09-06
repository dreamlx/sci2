FactoryBot.define do
  factory :fee_type do
    sequence(:name) { |n| "费用类型#{n}" }
    sequence(:meeting_name) { |n| "会议类型#{n}" }
    reimbursement_type_code { ['EN', 'MN'].sample }
    sequence(:meeting_type_code) { |n| n.to_s.rjust(2, '0') }
    sequence(:expense_type_code) { |n| n.to_s.rjust(2, '0') }
    active { true }
  end
end
