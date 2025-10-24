# spec/models/express_receipt_work_order_spec.rb
require 'rails_helper'

RSpec.describe ExpressReceiptWorkOrder, type: :model do
  # 验证测试（不依赖其他模型）
  describe 'validations' do
    let(:valid_attributes) do
      {
        reimbursement: build_stubbed(:reimbursement),
        tracking_number: 'SF1234',
        received_at: Time.current,
        filling_id: '2025010001'
      }
    end

    subject { described_class.new(valid_attributes) }

    it 'validates presence of tracking_number' do
      work_order = described_class.new(valid_attributes.merge(tracking_number: nil))
      expect(work_order).not_to be_valid
      expect(work_order.errors[:tracking_number]).to include('不能为空')
    end

    it 'validates presence of received_at' do
      work_order = described_class.new(valid_attributes.merge(received_at: nil))
      expect(work_order).not_to be_valid
      expect(work_order.errors[:received_at]).to include('不能为空')
    end

    it 'validates presence of filling_id' do
      # Create a valid work order first, then remove filling_id to test validation
      work_order = create(:express_receipt_work_order)
      work_order.filling_id = nil
      expect(work_order).not_to be_valid
      expect(work_order.errors[:filling_id]).to include('不能为空')
    end

    it 'allows valid filling_id format' do
      work_order = described_class.new(valid_attributes.merge(filling_id: '2025010001'))
      work_order.valid? # Trigger validation without callbacks interfering
      expect(work_order.errors[:filling_id]).to be_empty
    end

    it 'rejects invalid filling_id format' do
      work_order = described_class.new(valid_attributes.merge(filling_id: 'invalid'))
      work_order.valid?
      expect(work_order.errors[:filling_id]).to include('是无效的')
    end

    it 'rejects filling_id with 9 digits' do
      work_order = described_class.new(valid_attributes.merge(filling_id: '123456789'))
      work_order.valid?
      expect(work_order.errors[:filling_id]).to include('是无效的')
    end

    it 'rejects filling_id with 11 digits' do
      work_order = described_class.new(valid_attributes.merge(filling_id: '12345678901'))
      work_order.valid?
      expect(work_order.errors[:filling_id]).to include('是无效的')
    end

    describe 'status validation' do
      it "allows 'completed' status" do
        work_order = described_class.new(valid_attributes.merge(status: 'completed'))
        work_order.valid?
        expect(work_order.errors[:status]).to be_empty
      end

      it "rejects 'pending' status" do
        work_order = create(:express_receipt_work_order) # Create with default 'completed' status
        work_order.status = 'pending' # Try to change to invalid status
        work_order.valid?
        expect(work_order.errors[:status]).to include('不包含于列表中')
      end
    end

    describe 'filling_id uniqueness' do
      let!(:existing_work_order) { create(:express_receipt_work_order, filling_id: '2025010001') }

      it 'should not allow duplicate filling_id' do
        new_work_order = build(:express_receipt_work_order, filling_id: '2025010001')
        expect(new_work_order).not_to be_valid
        expect(new_work_order.errors[:filling_id]).to include('已经被使用')
      end
    end
  end

  # 初始化回调测试
  describe 'callbacks' do
    it 'sets default status to completed on create' do
      reimbursement = build_stubbed(:reimbursement)
      work_order = ExpressReceiptWorkOrder.new(reimbursement: reimbursement, tracking_number: 'SF1234')
      work_order.valid?
      expect(work_order.status).to eq('completed')
    end
  end

  # 填充ID生成测试
  describe 'filling_id generation' do
    let(:reimbursement) { create(:reimbursement) }

    it 'generates filling_id during validation' do
      work_order = build(:express_receipt_work_order, reimbursement: reimbursement, tracking_number: 'SF1234',
                                                      received_at: Time.current)
      expect(work_order.filling_id).to be_nil
      work_order.valid?
      expect(work_order.filling_id).to match(/\A\d{10}\z/)
    end

    it 'uses FillingIdGenerator to generate filling_id' do
      current_time = Time.current
      work_order = build(:express_receipt_work_order, reimbursement: reimbursement, tracking_number: 'SF1234',
                                                      received_at: current_time)
      expect(FillingIdGenerator).to receive(:generate).with(current_time).and_return('2025010001')
      work_order.valid?
      expect(work_order.filling_id).to eq('2025010001')
    end

    it 'generates unique filling_ids for different work orders' do
      work_order1 = create(:express_receipt_work_order, reimbursement: reimbursement, tracking_number: 'SF1234')
      work_order2 = create(:express_receipt_work_order, reimbursement: reimbursement, tracking_number: 'SF5678')
      expect(work_order1.filling_id).not_to eq(work_order2.filling_id)
    end
  end

  # 业务方法测试
  describe '#mark_reimbursement_as_received' do
    it 'calls mark_as_received on reimbursement with received_at' do
      # 创建一个简单的测试对象，避免工厂复杂性
      reimbursement = create(:reimbursement)
      work_order = ExpressReceiptWorkOrder.new(
        reimbursement: reimbursement,
        tracking_number: 'SF1234',
        status: 'completed'
      )

      received_time = Time.current - 1.day
      work_order.received_at = received_time

      expect(reimbursement).to receive(:mark_as_received).with(received_time)
      work_order.mark_reimbursement_as_received
    end

    it 'calls mark_as_received with current time if received_at is nil' do
      # 创建一个简单的测试对象，避免工厂复杂性
      reimbursement = create(:reimbursement)
      work_order = ExpressReceiptWorkOrder.new(
        reimbursement: reimbursement,
        tracking_number: 'SF1234',
        status: 'completed'
      )

      work_order.received_at = nil

      # 使用 be_within 匹配当前时间
      expect(reimbursement).to receive(:mark_as_received) do |time|
        expect(time).to be_within(1.second).of(Time.current)
      end

      work_order.mark_reimbursement_as_received
    end
  end

  # 继承测试
  describe 'inheritance' do
    it 'inherits from WorkOrder' do
      expect(described_class.superclass).to eq(WorkOrder)
    end
  end
end
