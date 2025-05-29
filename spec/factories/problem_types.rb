FactoryBot.define do
  factory :problem_type do
    sequence(:code) { |n| "PT#{n}" }
    title { "Test Problem Type" }
    sop_description { "Standard Operating Procedure for this problem type" }
    standard_handling { "Standard handling instructions for this problem type" }
    association :fee_type
    active { true }
  end
end
