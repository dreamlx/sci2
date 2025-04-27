FactoryBot.define do
  factory :communication_record do
    association :communication_work_order
    content { "沟通内容示例" }
    communicator_role { "auditor" }
    communicator_name { "审核人员" }
    communication_method { "email" }
    recorded_at { Time.current }
  end
end