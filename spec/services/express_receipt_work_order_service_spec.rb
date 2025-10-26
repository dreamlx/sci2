# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExpressReceiptWorkOrderService, type: :service do
  let(:admin_user) { AdminUser.create!(email: 'admin@test.com', password: 'password123') }

  let(:reimbursement) do
    Reimbursement.create!(
      invoice_number: 'INV-001',
      document_name: '测试报销单',
      status: 'processing',
      is_electronic: true
    )
  end

  let(:express_receipt_work_order) do
    ExpressReceiptWorkOrder.create!(
      reimbursement: reimbursement,
      tracking_number: 'EXP123456',
      courier_name: '顺丰速运',
      received_at: Time.current,
      created_by: admin_user.id
    )
  end

  before do
    Current.admin_user = admin_user
  end

  after do
    Current.admin_user = nil
  end

  describe 'initialization' do
    it 'creates service with valid work order' do
      service = described_class.new(express_receipt_work_order, admin_user)

      expect(service).to be_a(described_class)
    end

    it 'raises error for invalid work order type' do
      invalid_order = double('NotExpressReceiptWorkOrder')

      expect do
        described_class.new(invalid_order, admin_user)
      end.to raise_error(ArgumentError, 'Expected ExpressReceiptWorkOrder')
    end

    it 'sets Current.admin_user during initialization' do
      described_class.new(express_receipt_work_order, admin_user)

      expect(Current.admin_user).to eq(admin_user)
    end
  end

  describe '#work_order' do
    it 'returns the express receipt work order' do
      service = described_class.new(express_receipt_work_order, admin_user)

      expect(service.work_order).to eq(express_receipt_work_order)
    end
  end

  describe '#reimbursement' do
    it 'returns the associated reimbursement' do
      service = described_class.new(express_receipt_work_order, admin_user)

      expect(service.reimbursement).to eq(reimbursement)
    end
  end

  describe '#tracking_number' do
    it 'returns the tracking number' do
      service = described_class.new(express_receipt_work_order, admin_user)

      expect(service.tracking_number).to eq('EXP123456')
    end
  end

  describe '#received_at' do
    it 'returns the received timestamp' do
      service = described_class.new(express_receipt_work_order, admin_user)

      expect(service.received_at).to be_within(1.second).of(Time.current)
    end
  end

  describe '#update_tracking_info' do
    let(:service) { described_class.new(express_receipt_work_order, admin_user) }

    it 'updates tracking number' do
      new_params = { tracking_number: 'NEW123', courier_name: '中通快递' }

      service.update_tracking_info(new_params)

      expect(express_receipt_work_order.reload.tracking_number).to eq('NEW123')
      expect(express_receipt_work_order.courier_name).to eq('中通快递')
    end

    it 'updates courier name' do
      new_params = { courier_name: '圆通速递' }

      service.update_tracking_info(new_params)

      expect(express_receipt_work_order.reload.courier_name).to eq('圆通速递')
    end

    it 'updates received_at timestamp' do
      new_time = 2.days.ago
      new_params = { received_at: new_time }

      service.update_tracking_info(new_params)

      expect(express_receipt_work_order.reload.received_at).to be_within(1.second).of(new_time)
    end

    it 'only updates allowed parameters' do
      # Try to update disallowed parameters
      new_params = {
        tracking_number: 'NEW123',
        reimbursement_id: 999,
        created_by: 999
      }

      service.update_tracking_info(new_params)

      expect(express_receipt_work_order.reload.tracking_number).to eq('NEW123')
      expect(express_receipt_work_order.reimbursement_id).not_to eq(999)
      expect(express_receipt_work_order.created_by).to eq(admin_user.id)
    end
  end
end
