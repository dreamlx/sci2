FactoryBot.define do
  factory :admin_user do
    sequence(:email) { |n| "test_admin_user_#{n}@example.com" }
    password { 'password' }
    password_confirmation { 'password' }
  end

  # Add a simple validation test for the factory
  RSpec.describe "AdminUser factory" do
    it "is valid" do
      expect(build(:admin_user)).to be_valid
    end
  end
end
