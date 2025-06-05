FactoryBot.define do
  factory :fee_type do
    sequence(:code) { |n| "FT#{n.to_s.rjust(3, '0')}" }
    sequence(:title) { |n| "费用类型#{n}" }
    meeting_type { ["个人", "学术"].sample }
    active { true }
  end
end
