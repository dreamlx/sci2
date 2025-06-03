# spec/models/work_order_operation_spec.rb
require 'rails_helper'

RSpec.describe WorkOrderOperation, type: :model do
  describe 'associations' do
    it { should belong_to(:work_order) }
    it { should belong_to(:admin_user) }
  end
  
  describe 'validations' do
    it { should validate_presence_of(:operation_type) }
  end
  
  describe 'scopes' do
    let!(:work_order) { create(:audit_work_order) }
    let!(:admin_user) { create(:admin_user) }
    let!(:operation1) { create(:work_order_operation,
                              work_order: work_order,
                              admin_user: admin_user,
                              operation_type: 'create',
                              created_at: 1.day.ago) }
    let!(:operation2) { create(:work_order_operation,
                              work_order: work_order,
                              admin_user: admin_user,
                              operation_type: 'update',
                              created_at: 2.days.ago) }
    let!(:operation3) { create(:work_order_operation,
                              work_order: create(:audit_work_order),
                              operation_type: 'status_change',
                              created_at: 3.days.ago) }
    
    it 'filters by work_order_id' do
      expect(WorkOrderOperation.by_work_order(work_order.id)).to match_array([operation1, operation2])
    end
    
    it 'filters by admin_user_id' do
      expect(WorkOrderOperation.by_admin_user(admin_user.id)).to match_array([operation1, operation2])
    end
    
    it 'filters by operation_type' do
      expect(WorkOrderOperation.by_operation_type('create')).to match_array([operation1])
      expect(WorkOrderOperation.by_operation_type('update')).to match_array([operation2])
      expect(WorkOrderOperation.by_operation_type('status_change')).to match_array([operation3])
    end
    
    it 'orders by created_at desc' do
      expect(WorkOrderOperation.recent_first).to eq([operation1, operation2, operation3])
    end
  end
  
  describe '#operation_type_display' do
    it 'returns the Chinese translation of the operation type' do
      operation = build(:work_order_operation, work_order: build(:audit_work_order), operation_type: 'create')
      expect(operation.operation_type_display).to eq('创建工单')
      
      operation.operation_type = 'update'
      expect(operation.operation_type_display).to eq('更新工单')
      
      operation.operation_type = 'status_change'
      expect(operation.operation_type_display).to eq('状态变更')
      
      operation.operation_type = 'add_problem'
      expect(operation.operation_type_display).to eq('添加问题')
      
      operation.operation_type = 'remove_problem'
      expect(operation.operation_type_display).to eq('移除问题')
      
      operation.operation_type = 'modify_problem'
      expect(operation.operation_type_display).to eq('修改问题')
    end
  end
  
  describe 'JSON parsing methods' do
    let(:operation) { build(:work_order_operation, work_order: build(:audit_work_order)) }
    
    describe '#details_hash' do
      it 'returns an empty hash when details is nil' do
        operation.details = nil
        expect(operation.details_hash).to eq({})
      end
      
      it 'returns a hash when details is valid JSON' do
        operation.details = '{"key":"value"}'
        expect(operation.details_hash).to eq({"key" => "value"})
      end
      
      it 'returns an empty hash when details is invalid JSON' do
        operation.details = 'invalid json'
        expect(operation.details_hash).to eq({})
      end
    end
    
    describe '#previous_state_hash' do
      it 'returns an empty hash when previous_state is nil' do
        operation.previous_state = nil
        expect(operation.previous_state_hash).to eq({})
      end
      
      it 'returns a hash when previous_state is valid JSON' do
        operation.previous_state = '{"status":"pending"}'
        expect(operation.previous_state_hash).to eq({"status" => "pending"})
      end
      
      it 'returns an empty hash when previous_state is invalid JSON' do
        operation.previous_state = 'invalid json'
        expect(operation.previous_state_hash).to eq({})
      end
    end
    
    describe '#current_state_hash' do
      it 'returns an empty hash when current_state is nil' do
        operation.current_state = nil
        expect(operation.current_state_hash).to eq({})
      end
      
      it 'returns a hash when current_state is valid JSON' do
        operation.current_state = '{"status":"approved"}'
        expect(operation.current_state_hash).to eq({"status" => "approved"})
      end
      
      it 'returns an empty hash when current_state is invalid JSON' do
        operation.current_state = 'invalid json'
        expect(operation.current_state_hash).to eq({})
      end
    end
  end
end