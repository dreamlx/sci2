require 'rails_helper'

RSpec.describe WorkOrderStatusChange, type: :model do
  describe "validations" do
    it { should validate_presence_of(:work_order_type) }
    it { should validate_presence_of(:work_order_id) }
    it { should validate_presence_of(:to_status) }
    it { should validate_presence_of(:changed_at) }
  end

  describe "associations" do
    it { should belong_to(:work_order).optional }
  end

  describe "scopes" do
    before do
      create(:work_order_status_change, work_order_type: 'express_receipt', to_status: 'received')
      create(:work_order_status_change, work_order_type: 'audit', to_status: 'pending')
      create(:work_order_status_change, work_order_type: 'communication', to_status: 'open')
    end

    it "returns changes for express receipt work orders" do
      expect(WorkOrderStatusChange.for_express_receipt_work_orders.count).to eq(1)
    end

    it "returns changes for audit work orders" do
      expect(WorkOrderStatusChange.for_audit_work_orders.count).to eq(1)
    end

    it "returns changes for communication work orders" do
      expect(WorkOrderStatusChange.for_communication_work_orders.count).to eq(1)
    end

    it "returns changes in descending order by changed_at" do
      create(:work_order_status_change, changed_at: 1.day.ago)
      changes = WorkOrderStatusChange.recent
      expect(changes.first.changed_at).to be > changes.last.changed_at
    end

    it "returns changes by changed_by" do
      create(:work_order_status_change, changed_by: 999)
      expect(WorkOrderStatusChange.by_changed_by(999).count).to eq(1)
    end
  end

  describe "methods" do
    describe "#work_order_object" do
      it "returns express receipt work order when work_order_type is 'express_receipt'" do
        work_order = create(:express_receipt_work_order)
        status_change = create(:work_order_status_change, work_order_type: 'express_receipt', work_order_id: work_order.id)
        expect(status_change.work_order_object).to eq(work_order)
      end

      it "returns audit work order when work_order_type is 'audit'" do
        work_order = create(:audit_work_order)
        status_change = create(:work_order_status_change, work_order_type: 'audit', work_order_id: work_order.id)
        expect(status_change.work_order_object).to eq(work_order)
      end

      it "returns communication work order when work_order_type is 'communication'" do
        work_order = create(:communication_work_order)
        status_change = create(:work_order_status_change, work_order_type: 'communication', work_order_id: work_order.id)
        expect(status_change.work_order_object).to eq(work_order)
      end

      it "returns nil when work order does not exist" do
        status_change = create(:work_order_status_change, work_order_type: 'audit', work_order_id: 999999)
        expect(status_change.work_order_object).to be_nil
      end
    end

    describe "#changed_by_user" do
      it "returns admin user when changed_by is present" do
        admin_user = create(:admin_user)
        status_change = create(:work_order_status_change, changed_by: admin_user.id)
        expect(status_change.changed_by_user).to eq(admin_user)
      end

      it "returns nil when changed_by is not present" do
        status_change = create(:work_order_status_change, changed_by: nil)
        expect(status_change.changed_by_user).to be_nil
      end
    end

    describe "#status_change_description" do
      it "returns description with from_status and to_status" do
        status_change = create(:work_order_status_change, from_status: 'pending', to_status: 'processing')
        expect(status_change.status_change_description).to eq("从 pending 变更为 processing")
      end

      it "returns description with '(初始状态)' when from_status is nil" do
        status_change = create(:work_order_status_change, from_status: nil, to_status: 'pending')
        expect(status_change.status_change_description).to eq("从 (初始状态) 变更为 pending")
      end
    end
  end
end