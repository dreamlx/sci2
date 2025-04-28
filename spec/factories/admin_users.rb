FactoryBot.define do
  factory :admin_user do
    sequence(:email) { |n| "admin_user#{n}@example.com" }
    password { 'password' }
    password_confirmation { 'password' }
  end
end
