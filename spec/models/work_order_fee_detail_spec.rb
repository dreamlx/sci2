require 'rails_helper'

RSpec.describe WorkOrderFeeDetail, type: :model do
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
      # Create a record first
      # Use build and save to avoid callbacks
      admin_user = AdminUser.create!(email: 'admin@example.com', password: 'password')
      Current.admin_user = admin_user

      reimbursement = Reimbursement.create!(
        invoice_number: 'INV-001',
        document_name: '个人报销单',
        status: 'processing',
        is_electronic: true
      )

      fee_detail = FeeDetail.create!(
        document_number: reimbursement.invoice_number,
        fee_type: '月度交通费',
        amount: 100.0,
        fee_date: Date.today,
        verification_status: 'pending'
      )

      # Create work order without callbacks
      work_order = AuditWorkOrder.new(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )
      work_order.save(validate: false)

      WorkOrderFeeDetail.create!(
        work_order_id: work_order.id,
        fee_detail_id: fee_detail.id
      )

      # Try to create a duplicate
      duplicate = WorkOrderFeeDetail.new(
        work_order_id: work_order.id,
        fee_detail_id: fee_detail.id
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:fee_detail_id]).to include('已经与此工单关联')

      Current.admin_user = nil
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
  describe 'methods' do
    let(:admin_user) { AdminUser.create!(email: 'admin@example.com', password: 'password') }

    before do
      Current.admin_user = admin_user
    end

    after do
      Current.admin_user = nil
    end

    it 'returns the associated work order' do
      reimbursement = Reimbursement.create!(
        invoice_number: 'INV-001',
        document_name: '个人报销单',
        status: 'processing',
        is_electronic: true
      )

      fee_detail = FeeDetail.create!(
        document_number: reimbursement.invoice_number,
        fee_type: '月度交通费',
        amount: 100.0,
        fee_date: Date.today,
        verification_status: 'pending'
      )

      # Create work order without callbacks
      work_order = AuditWorkOrder.new(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )
      work_order.save(validate: false)

      work_order_fee_detail = WorkOrderFeeDetail.create!(
        work_order_id: work_order.id,
        fee_detail_id: fee_detail.id
      )

      expect(work_order_fee_detail.work_order).to eq(work_order)
    end

    it 'returns the associated fee detail' do
      reimbursement = Reimbursement.create!(
        invoice_number: 'INV-001',
        document_name: '个人报销单',
        status: 'processing',
        is_electronic: true
      )

      fee_detail = FeeDetail.create!(
        document_number: reimbursement.invoice_number,
        fee_type: '月度交通费',
        amount: 100.0,
        fee_date: Date.today,
        verification_status: 'pending'
      )

      # Create work order without callbacks
      work_order = AuditWorkOrder.new(
        reimbursement: reimbursement,
        status: 'pending',
        created_by: admin_user.id
      )
      work_order.save(validate: false)

      work_order_fee_detail = WorkOrderFeeDetail.create!(
        work_order_id: work_order.id,
        fee_detail_id: fee_detail.id
      )

      expect(work_order_fee_detail.fee_detail).to eq(fee_detail)
    end
  end

  # Callbacks
  describe 'integration with fee detail status' do
    let(:admin_user) { AdminUser.create!(email: 'admin@example.com', password: 'password') }

    before do
      Current.admin_user = admin_user
    end

    after do
      Current.admin_user = nil
    end

    it 'creates a valid association between work order and fee detail' do
      # Setup
      reimbursement = Reimbursement.create!(
        invoice_number: 'INV-001',
        document_name: '个人报销单',
        status: 'processing',
        is_electronic: true
      )

      fee_detail = FeeDetail.create!(
        document_number: reimbursement.invoice_number,
        fee_type: '月度交通费',
        amount: 100.0,
        fee_date: Date.today,
        verification_status: 'pending'
      )

      # Create work order without callbacks
      work_order = AuditWorkOrder.new(
        reimbursement: reimbursement,
        status: 'approved',
        created_by: admin_user.id
      )
      work_order.save(validate: false)

      # Create the association
      work_order_fee_detail = WorkOrderFeeDetail.create!(
        work_order_id: work_order.id,
        fee_detail_id: fee_detail.id
      )

      # Verify the association was created
      expect(work_order_fee_detail).to be_persisted
      expect(work_order_fee_detail.work_order).to eq(work_order)
      expect(work_order_fee_detail.fee_detail).to eq(fee_detail)
    end

    it 'updates fee detail status after destroy' do
      # Setup
      reimbursement = Reimbursement.create!(
        invoice_number: 'INV-001',
        document_name: '个人报销单',
        status: 'processing',
        is_electronic: true
      )

      fee_detail = FeeDetail.create!(
        document_number: reimbursement.invoice_number,
        fee_type: '月度交通费',
        amount: 100.0,
        fee_date: Date.today,
        verification_status: 'pending'
      )

      # Create work order without callbacks
      work_order = AuditWorkOrder.new(
        reimbursement: reimbursement,
        status: 'approved',
        created_by: admin_user.id
      )
      work_order.save(validate: false)

      # Create the association
      association = WorkOrderFeeDetail.create!(
        work_order_id: work_order.id,
        fee_detail_id: fee_detail.id
      )

      # Expect the FeeDetailStatusService to be called
      expect_any_instance_of(FeeDetailStatusService).to receive(:update_status).once

      # Destroy the association
      association.destroy
    end

    it 'allows multiple work orders to be associated with a fee detail' do
      # Setup
      reimbursement = Reimbursement.create!(
        invoice_number: 'INV-001',
        document_name: '个人报销单',
        status: 'processing',
        is_electronic: true
      )

      fee_detail = FeeDetail.create!(
        document_number: reimbursement.invoice_number,
        fee_type: '月度交通费',
        amount: 100.0,
        fee_date: Date.today,
        verification_status: 'pending'
      )

      # Create work orders without callbacks
      work_order1 = AuditWorkOrder.new(
        reimbursement: reimbursement,
        status: 'approved',
        created_by: admin_user.id
      )
      work_order1.save(validate: false)

      work_order2 = AuditWorkOrder.new(
        reimbursement: reimbursement,
        status: 'rejected',
        created_by: admin_user.id
      )
      work_order2.save(validate: false)

      # Create associations
      work_order_fee_detail1 = WorkOrderFeeDetail.create!(
        work_order_id: work_order1.id,
        fee_detail_id: fee_detail.id
      )

      work_order_fee_detail2 = WorkOrderFeeDetail.create!(
        work_order_id: work_order2.id,
        fee_detail_id: fee_detail.id
      )

      # Verify the associations were created
      expect(work_order_fee_detail1).to be_persisted
      expect(work_order_fee_detail2).to be_persisted

      # Verify the fee detail has both work orders
      expect(fee_detail.work_order_fee_details.count).to eq(2)
    end
  end
end
