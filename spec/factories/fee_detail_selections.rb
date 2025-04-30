# spec/factories/fee_detail_selections.rb
FactoryBot.define do
  factory :fee_detail_selection do
    fee_detail
    association :work_order, factory: :audit_work_order
    verification_status { "pending" }
    verification_comment { "测试验证备注" }
    # Remove verified_at and verified_by fields as they seem to be undefined
  end

  # Add a simple validation test for the factory
  RSpec.describe "FeeDetailSelection factory" do
    it "is valid" do
      # Need to create associated records for the factory to be valid
      fee_detail = create(:fee_detail)
      work_order = create(:audit_work_order)
      expect(build(:fee_detail_selection, fee_detail: fee_detail, work_order: work_order)).to be_valid
    end
  end
end