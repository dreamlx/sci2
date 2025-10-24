# spec/factories/communication_records.rb
FactoryBot.define do
  factory :communication_record do
    communication_work_order
    content { '测试沟通内容' }
    communicator_role { '财务人员' }
    communicator_name { '测试沟通人' }
    communication_method { '电话' }
    recorded_at { Time.current }
  end
end
