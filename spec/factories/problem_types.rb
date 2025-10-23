FactoryBot.define do
  factory :problem_type do
    sequence(:code) { |n| n.to_s.rjust(2, '0') } # This maps to issue_code via alias
    sequence(:title) { |n| "问题类型#{n}" }
    sop_description { "标准操作描述..." }
    standard_handling { "标准处理方式..." }
    active { true }
    association :fee_type
  end
end
