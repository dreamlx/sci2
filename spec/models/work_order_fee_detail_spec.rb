require 'rails_helper'

RSpec.describe WorkOrderFeeDetail, type: :model do
  # Use shared test data setup for better maintainability
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement) }
  let(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }
  let(:work_order) { create(:audit_work_order, reimbursement: reimbursement) }

  # Associations
  describe 'associations' do
    it { should belong_to(:work_order) }
    it { should belong_to(:fee_detail) }
  end

  # Validations
  describe 'validations' do
    it { should validate_presence_of(:fee_detail_id) }
    it { should validate_presence_of(:work_order_id) }

    it 'validates uniqueness of fee_detail_id scoped to work_order_id' do
      # Create an association
      create(:work_order_fee_detail, work_order: work_order, fee_detail: fee_detail)

      # Try to create a duplicate
      duplicate = build(:work_order_fee_detail, work_order: work_order, fee_detail: fee_detail)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:fee_detail_id]).to include('已经与此工单关联')
    end
  end

  # Scopes
  describe 'scopes' do
    it 'has a scope for filtering by fee_detail' do
      expect(WorkOrderFeeDetail).to respond_to(:by_fee_detail)
    end

    it 'has a scope for filtering by work_order' do
      expect(WorkOrderFeeDetail).to respond_to(:by_work_order)
    end
  end

  # Methods
  describe 'associations behavior' do
    it 'returns the associated work order' do
      work_order_fee_detail = create(:work_order_fee_detail, work_order: work_order, fee_detail: fee_detail)
      expect(work_order_fee_detail.work_order).to eq(work_order)
    end

    it 'returns the associated fee detail' do
      work_order_fee_detail = create(:work_order_fee_detail, work_order: work_order, fee_detail: fee_detail)
      expect(work_order_fee_detail.fee_detail).to eq(fee_detail)
    end
  end

  # Integration behavior
  describe 'association behavior' do
    it 'creates a valid association between work order and fee detail' do
      work_order_fee_detail = create(:work_order_fee_detail, work_order: work_order, fee_detail: fee_detail)

      expect(work_order_fee_detail).to be_persisted
      expect(work_order_fee_detail.work_order).to eq(work_order)
      expect(work_order_fee_detail.fee_detail).to eq(fee_detail)
    end

    it 'updates fee detail status after destroy' do
      work_order_fee_detail = create(:work_order_fee_detail, work_order: work_order, fee_detail: fee_detail)

      # Expect the FeeDetailStatusService to be called
      expect_any_instance_of(FeeDetailStatusService).to receive(:update_status).once

      # Destroy the association
      work_order_fee_detail.destroy
    end

    it 'allows multiple work orders to be associated with a fee detail' do
      work_order1 = create(:audit_work_order, reimbursement: reimbursement)
      work_order2 = create(:communication_work_order, reimbursement: reimbursement)

      # Create associations
      work_order_fee_detail1 = create(:work_order_fee_detail, work_order: work_order1, fee_detail: fee_detail)
      work_order_fee_detail2 = create(:work_order_fee_detail, work_order: work_order2, fee_detail: fee_detail)

      # Verify the associations were created
      expect(work_order_fee_detail1).to be_persisted
      expect(work_order_fee_detail2).to be_persisted

      # Verify the fee detail has both work orders
      expect(fee_detail.work_order_fee_details.count).to eq(2)
    end
  end
end
