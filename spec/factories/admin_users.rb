FactoryBot.define do
  factory :admin_user do
    sequence(:email) { |n| "test_admin_user_#{n}@example.com" }
    password { 'password' }
    password_confirmation { 'password' }
  end
end
