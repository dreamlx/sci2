FactoryBot.define do
  factory :admin_user do
    sequence(:email) { |n| "test_admin_user_#{n}@example.com" }
    password { 'password' }
    password_confirmation { 'password' }
    role { 'admin' }
    
    trait :super_admin do
      role { 'super_admin' }
    end
    
    trait :admin do
      role { 'admin' }
    end
  end
end
