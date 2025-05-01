# spec/models/fee_detail_selection_spec.rb
require 'rails_helper'

RSpec.describe FeeDetailSelection, type: :model do
  let(:fee_detail) { create(:fee_detail) }
  let(:audit_work_order) { create(:audit_work_order) } # Use a subclass for polymorphic association

  # Validations
  describe "validations" do
    it { should validate_presence_of(:fee_detail_id) }
    it { should validate_presence_of(:work_order_id) }
    it { should validate_presence_of(:work_order_type) }
    # Test uniqueness with scope
    it "validates uniqueness of fee_detail_id scoped to work_order" do
      create(:fee_detail_selection, fee_detail: fee_detail, work_order: audit_work_order)
      should validate_uniqueness_of(:fee_detail_id).scoped_to([:work_order_id, :work_order_type]).with_message("已被选择")
    end
  end

  # Associations
  describe "associations" do
    it { should belong_to(:fee_detail) }
    it { should belong_to(:work_order) } # Polymorphic association test
  end

  # Ransackable methods
  describe "ransackable methods" do
    it "includes expected attributes" do
      expect(FeeDetailSelection.ransackable_attributes).to include(
        "id", "fee_detail_id", "work_order_id", "work_order_type", "verification_comment", "verifier_id", "verified_at", "created_at", "updated_at"
      )
      # verification_status has been removed from the model
      expect(FeeDetailSelection.ransackable_attributes).not_to include("verification_status")
    end

    it "includes expected associations" do
      expect(FeeDetailSelection.ransackable_associations).to include(
        "fee_detail", "work_order"
      )
    end
  end
end