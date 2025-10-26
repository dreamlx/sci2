# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CommunicationRecord, type: :model do
  let(:admin_user) { AdminUser.create!(email: 'admin@test.com', password: 'password123') }

  let(:reimbursement) do
    Reimbursement.create!(
      invoice_number: 'INV-001',
      document_name: '测试报销单',
      status: 'processing',
      is_electronic: true
    )
  end

  let(:communication_work_order) do
    CommunicationWorkOrder.create!(
      reimbursement: reimbursement,
      status: 'pending',
      created_by: admin_user.id,
      audit_comment: '需要与申请人沟通费用明细问题',
      communication_method: '电话'
    )
  end

  describe 'associations' do
    it { is_expected.to belong_to(:communication_work_order).class_name('CommunicationWorkOrder') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_presence_of(:communicator_role) }
    it { is_expected.to validate_presence_of(:communication_work_order_id) }
  end

  describe 'callbacks' do
    describe 'before_create :set_recorded_at' do
      it 'sets recorded_at to current time on create' do
        record = CommunicationRecord.create!(
          communication_work_order: communication_work_order,
          content: '测试沟通记录',
          communicator_role: '审核人员',
          communicator_name: '张三'
        )

        expect(record.recorded_at).to be_within(1.second).of(Time.current)
      end

      it 'does not override manually set recorded_at' do
        custom_time = 2.days.ago
        record = CommunicationRecord.create!(
          communication_work_order: communication_work_order,
          content: '测试沟通记录',
          communicator_role: '审核人员',
          recorded_at: custom_time
        )

        expect(record.recorded_at).to be_within(1.second).of(custom_time)
      end
    end
  end

  describe '.ransackable_attributes' do
    it 'includes expected searchable attributes' do
      attributes = described_class.ransackable_attributes

      expect(attributes).to include('id')
      expect(attributes).to include('communication_work_order_id')
      expect(attributes).to include('content')
      expect(attributes).to include('communicator_role')
      expect(attributes).to include('communicator_name')
      expect(attributes).to include('communication_method')
      expect(attributes).to include('recorded_at')
      expect(attributes).to include('created_at')
      expect(attributes).to include('updated_at')
    end
  end

  describe '.ransackable_associations' do
    it 'includes expected searchable associations' do
      associations = described_class.ransackable_associations

      expect(associations).to include('communication_work_order')
    end
  end

  describe 'creating communication records' do
    it 'creates a valid communication record' do
      record = CommunicationRecord.create!(
        communication_work_order: communication_work_order,
        content: '已电话联系申请人，确认费用详情',
        communicator_role: '审核人员',
        communicator_name: '李四',
        communication_method: '电话'
      )

      expect(record).to be_persisted
      expect(record.content).to eq('已电话联系申请人，确认费用详情')
      expect(record.communicator_role).to eq('审核人员')
      expect(record.communicator_name).to eq('李四')
      expect(record.communication_method).to eq('电话')
    end

    it 'requires content' do
      record = CommunicationRecord.new(
        communication_work_order: communication_work_order,
        communicator_role: '审核人员'
      )

      expect(record).not_to be_valid
      expect(record.errors[:content]).to include("不能为空")
    end

    it 'requires communicator_role' do
      record = CommunicationRecord.new(
        communication_work_order: communication_work_order,
        content: '测试内容'
      )

      expect(record).not_to be_valid
      expect(record.errors[:communicator_role]).to include("不能为空")
    end

    it 'requires communication_work_order_id' do
      record = CommunicationRecord.new(
        content: '测试内容',
        communicator_role: '审核人员'
      )

      expect(record).not_to be_valid
      expect(record.errors[:communication_work_order_id]).to include("不能为空")
    end
  end

  describe 'querying records' do
    before do
      CommunicationRecord.create!(
        communication_work_order: communication_work_order,
        content: '第一次沟通',
        communicator_role: '审核人员',
        communicator_name: '张三',
        recorded_at: 2.days.ago
      )

      CommunicationRecord.create!(
        communication_work_order: communication_work_order,
        content: '第二次沟通',
        communicator_role: '申请人',
        communicator_name: '李四',
        recorded_at: 1.day.ago
      )
    end

    it 'retrieves all records for a work order' do
      records = CommunicationRecord.where(communication_work_order: communication_work_order)

      expect(records.count).to eq(2)
    end

    it 'can filter by communicator role' do
      records = CommunicationRecord.where(communicator_role: '审核人员')

      expect(records.count).to eq(1)
      expect(records.first.communicator_name).to eq('张三')
    end
  end
end
