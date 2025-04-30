# spec/factories/work_order_status_changes.rb
FactoryBot.define do
  factory :work_order_status_change do
    association :work_order, factory: :audit_work_order
    work_order_type { "AuditWorkOrder" }
    from_status { nil }
    to_status { "pending" }
    changed_at { Time.current }
    # Remove changed_by field as it seems to be undefined
  end

  # Add a simple validation test for the factory
  RSpec.describe "WorkOrderStatusChange factory" do
    it "is valid" do
      # Need to create an associated work order for the factory to be valid
      work_order = create(:audit_work_order)
      expect(build(:work_order_status_change, work_order: work_order)).to be_valid
    end
  end
end