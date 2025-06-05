FactoryBot.define do
  factory :problem_type do
    sequence(:code) { |n| "PT#{n.to_s.rjust(3, '0')}" }
    sequence(:title) { |n| "问题类型#{n}" }
    sequence(:sop_description) { |n| "标准操作描述#{n}" }
    sequence(:standard_handling) { |n| "标准处理方式#{n}" }
    association :fee_type
    active { true }
  end
end
