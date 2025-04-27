FactoryBot.define do
  factory :admin_user do
    email { "admin#{rand(1000)}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
  end
end
