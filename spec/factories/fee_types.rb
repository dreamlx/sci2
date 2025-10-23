FactoryBot.define do
  factory :fee_type do
    sequence(:name) { |n| "费用类型#{n}" }
    sequence(:meeting_name) { |n| "会议类型#{n}" }
    sequence(:reimbursement_type_code) { |n| ['EN', 'MN'][n % 2] }
    sequence(:meeting_type_code) { |n| (n + 10).to_s.rjust(2, '0') } # Start from 10 to avoid conflicts
    sequence(:expense_type_code) { |n| (n + 20).to_s.rjust(2, '0') } # Start from 20 to avoid conflicts
    active { true }
  end
end
