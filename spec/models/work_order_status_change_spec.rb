# spec/models/work_order_status_change_spec.rb
require 'rails_helper'

RSpec.describe WorkOrderStatusChange, type: :model do
  let(:audit_work_order) { create(:audit_work_order) } # Use a subclass for polymorphic association
  let(:admin_user) { create(:admin_user) }

  # Validations
  describe 'validations' do
    it { should validate_presence_of(:work_order_id) }
    it { should validate_presence_of(:work_order_type) }
    it { should validate_presence_of(:to_status) }
    it { should validate_presence_of(:changed_at) }
  end

  # Associations
  describe 'associations' do
    it { should belong_to(:work_order) } # Polymorphic association test
    it { should belong_to(:changer).class_name('AdminUser').optional }
  end

  # Scopes
  describe 'scopes' do
    let!(:audit_change) do
      create(:work_order_status_change, work_order: create(:audit_work_order), work_order_type: 'AuditWorkOrder')
    end
    let!(:communication_change) do
      create(:work_order_status_change, work_order: create(:communication_work_order),
                                        work_order_type: 'CommunicationWorkOrder')
    end

    it 'returns changes for audit work orders' do
      expect(WorkOrderStatusChange.for_audit_work_orders).to include(audit_change)
      expect(WorkOrderStatusChange.for_audit_work_orders).not_to include(communication_change)
    end

    it 'returns changes for communication work orders' do
      expect(WorkOrderStatusChange.for_communication_work_orders).to include(communication_change)
      expect(WorkOrderStatusChange.for_communication_work_orders).not_to include(audit_change)
    end

    # Assuming ExpressReceiptWorkOrder also has status changes recorded
    # it "returns changes for express receipt work orders" do
    #   express_receipt_change = create(:work_order_status_change, work_order: create(:express_receipt_work_order), work_order_type: 'ExpressReceiptWorkOrder')
    #   expect(WorkOrderStatusChange.for_express_receipt_work_orders).to include(express_receipt_change)
    #   expect(WorkOrderStatusChange.for_express_receipt_work_orders).not_to include(audit_change, communication_change)
    # end
  end

  # Ransackable methods
  describe 'ransackable methods' do
    it 'includes expected attributes' do
      expect(WorkOrderStatusChange.ransackable_attributes).to include(
        'id', 'work_order_type', 'work_order_id', 'from_status', 'to_status', 'changed_at', 'changed_by', 'created_at', 'updated_at'
      )
    end

    it 'includes expected associations' do
      expect(WorkOrderStatusChange.ransackable_associations).to include(
        'work_order', 'changer'
      )
    end
  end
end
