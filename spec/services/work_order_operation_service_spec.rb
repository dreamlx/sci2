# spec/services/work_order_operation_service_spec.rb
require 'rails_helper'

RSpec.describe WorkOrderOperationService, type: :service do
  let(:work_order) { create(:audit_work_order) }
  let(:admin_user) { create(:admin_user) }
  let(:service) { described_class.new(work_order, admin_user) }
  
  describe '#record_create' do
    it 'creates a new operation record with create type' do
      expect {
        service.record_create
      }.to change(WorkOrderOperation, :count).by(1)
      
      operation = WorkOrderOperation.last
      expect(operation.work_order).to eq(work_order)
      expect(operation.admin_user).to eq(admin_user)
      expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_CREATE)
      expect(operation.details_hash).to include('message' => '工单已创建')
      expect(operation.previous_state).to eq('null')
      expect(operation.current_state_hash).to include('id' => work_order.id)
    end
  end
  
  describe '#record_update' do
    it 'creates a new operation record with update type' do
      changed_attributes = { 'status' => 'pending' }
      
      expect {
        service.record_update(changed_attributes)
      }.to change(WorkOrderOperation, :count).by(1)
      
      operation = WorkOrderOperation.last
      expect(operation.work_order).to eq(work_order)
      expect(operation.admin_user).to eq(admin_user)
      expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_UPDATE)
      expect(operation.details_hash).to include('changed_attributes' => ['status'])
      expect(operation.previous_state_hash).to include('status' => 'pending')
    end
    
    it 'does not create a record if no attributes changed' do
      expect {
        service.record_update({})
      }.not_to change(WorkOrderOperation, :count)
    end
  end
  
  describe '#record_status_change' do
    it 'creates a new operation record with status_change type' do
      expect {
        service.record_status_change('pending', 'approved')
      }.to change(WorkOrderOperation, :count).by(1)
      
      operation = WorkOrderOperation.last
      expect(operation.work_order).to eq(work_order)
      expect(operation.admin_user).to eq(admin_user)
      expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_STATUS_CHANGE)
      expect(operation.details_hash).to include('from_status' => 'pending', 'to_status' => 'approved')
      expect(operation.previous_state_hash).to include('status' => 'pending')
      expect(operation.current_state_hash).to include('status' => 'approved')
    end
  end
  
  describe '#record_add_problem' do
    let(:fee_type) { create(:fee_type) }
    let(:problem_type) { create(:problem_type, fee_type: fee_type) }
    
    before do
      allow(work_order).to receive(:audit_comment_was).and_return(nil)
      allow(work_order).to receive(:audit_comment).and_return('New problem')
    end
    
    it 'creates a new operation record with add_problem type' do
      expect {
        service.record_add_problem(problem_type.id, 'New problem')
      }.to change(WorkOrderOperation, :count).by(1)
      
      operation = WorkOrderOperation.last
      expect(operation.work_order).to eq(work_order)
      expect(operation.admin_user).to eq(admin_user)
      expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_ADD_PROBLEM)
      expect(operation.details_hash).to include('problem_type_id' => problem_type.id)
      expect(operation.previous_state_hash).to include('audit_comment' => nil)
      expect(operation.current_state_hash).to include('audit_comment' => 'New problem')
    end
  end
  
  describe '#record_remove_problem' do
    let(:problem_type) { create(:problem_type) }
    
    it 'creates a new operation record with remove_problem type' do
      old_content = 'Old problem'
      
      expect {
        service.record_remove_problem(problem_type.id, old_content)
      }.to change(WorkOrderOperation, :count).by(1)
      
      operation = WorkOrderOperation.last
      expect(operation.work_order).to eq(work_order)
      expect(operation.admin_user).to eq(admin_user)
      expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM)
      expect(operation.details_hash).to include('problem_type_id' => problem_type.id)
      expect(operation.previous_state_hash).to include('audit_comment' => 'Old problem')
    end
  end
  
  describe '#record_modify_problem' do
    let(:problem_type) { create(:problem_type) }
    
    it 'creates a new operation record with modify_problem type' do
      old_text = 'Old problem'
      new_text = 'Modified problem'
      
      expect {
        service.record_modify_problem(problem_type.id, old_text, new_text)
      }.to change(WorkOrderOperation, :count).by(1)
      
      operation = WorkOrderOperation.last
      expect(operation.work_order).to eq(work_order)
      expect(operation.admin_user).to eq(admin_user)
      expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_MODIFY_PROBLEM)
      expect(operation.details_hash).to include('problem_type_id' => problem_type.id)
      expect(operation.previous_state_hash).to include('audit_comment' => 'Old problem')
      expect(operation.current_state_hash).to include('audit_comment' => 'Modified problem')
    end
  end
end