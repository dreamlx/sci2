# spec/factories/communication_records.rb
FactoryBot.define do
  factory :communication_record do
    association :communication_work_order
    content { "测试沟通内容" }
    communicator_role { "审核人" }
    communicator_name { "测试用户" }
    communication_method { "电话" }
    recorded_at { Time.current }
  end
end