require 'rails_helper'

RSpec.describe CommunicationRecord, type: :model do
  describe "validations" do
    it { should validate_presence_of(:content) }
    it { should validate_presence_of(:communicator_role) }
    it { should validate_presence_of(:communication_work_order_id) }
  end

  describe "associations" do
    it { should belong_to(:communication_work_order) }
  end

  describe "callbacks" do
    it "sets recorded_at before create if not provided" do
      record = build(:communication_record, recorded_at: nil)
      record.save
      expect(record.recorded_at).not_to be_nil
    end

    it "does not change recorded_at if already set" do
      time = 1.day.ago
      record = build(:communication_record, recorded_at: time)
      record.save
      expect(record.recorded_at).to be_within(1.second).of(time)
    end
  end
end