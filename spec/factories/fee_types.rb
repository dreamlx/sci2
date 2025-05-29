FactoryBot.define do
  factory :fee_type do
    sequence(:code) { |n| "FT#{n}" }
    title { "Test Fee Type" }
    meeting_type { "个人" }
    active { true }
    
    trait :personal do
      meeting_type { "个人" }
    end
    
    trait :academic do
      meeting_type { "学术论坛" }
    end
  end
end
