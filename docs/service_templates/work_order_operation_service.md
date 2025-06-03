# WorkOrderOperationService Template

This document provides a template for implementing the `WorkOrderOperationService` for tracking work order operations.

## Service File

```ruby
# app/services/work_order_operation_service.rb
class WorkOrderOperationService
  def initialize(work_order, admin_user)
    @work_order = work_order
    @admin_user = admin_user
  end
  
  # Record work order creation operation
  # @return [WorkOrderOperation] The created operation record
  def record_create
    record_operation(
      WorkOrderOperation::OPERATION_TYPE_CREATE,
      { message: "工单已创建" },
      nil,
      work_order_state
    )
  end
  
  # Record work order update operation
  # @param changed_attributes [Hash] A hash of changed attributes with their previous values
  # @return [WorkOrderOperation] The created operation record
  def record_update(changed_attributes)
    return nil if changed_attributes.empty?
    
    previous = {}
    current = {}
    
    changed_attributes.each do |attr, old_value|
      previous[attr] = old_value
      current[attr] = @work_order.send(attr)
    end
    
    record_operation(
      WorkOrderOperation::OPERATION_TYPE_UPDATE,
      { changed_attributes: changed_attributes.keys },
      previous,
      current
    )
  end
  
  # Record work order status change operation
  # @param from_status [String] The previous status
  # @param to_status [String] The new status
  # @return [WorkOrderOperation] The created operation record
  def record_status_change(from_status, to_status)
    record_operation(
      WorkOrderOperation::OPERATION_TYPE_STATUS_CHANGE,
      { from_status: from_status, to_status: to_status },
      { status: from_status },
      { status: to_status }
    )
  end
  
  # Record add problem operation
  # @param problem_type_id [Integer] The ID of the problem type
  # @param problem_text [String] The text of the problem
  # @return [WorkOrderOperation] The created operation record
  def record_add_problem(problem_type_id, problem_text)
    problem_type = ProblemType.find_by(id: problem_type_id)
    
    record_operation(
      WorkOrderOperation::OPERATION_TYPE_ADD_PROBLEM,
      {
        problem_type_id: problem_type_id,
        problem_type_code: problem_type&.code,
        problem_type_title: problem_type&.title
      },
      { audit_comment: @work_order.audit_comment_was },
      { audit_comment: @work_order.audit_comment }
    )
  end
  
  # Record remove problem operation
  # @param problem_type_id [Integer] The ID of the problem type
  # @param problem_text [String] The text of the problem
  # @return [WorkOrderOperation] The created operation record
  def record_remove_problem(problem_type_id, problem_text)
    problem_type = ProblemType.find_by(id: problem_type_id)
    
    record_operation(
      WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM,
      {
        problem_type_id: problem_type_id,
        problem_type_code: problem_type&.code,
        problem_type_title: problem_type&.title
      },
      { audit_comment: @work_order.audit_comment_was },
      { audit_comment: @work_order.audit_comment }
    )
  end
  
  # Record modify problem operation
  # @param problem_type_id [Integer] The ID of the problem type
  # @param old_text [String] The previous text of the problem
  # @param new_text [String] The new text of the problem
  # @return [WorkOrderOperation] The created operation record
  def record_modify_problem(problem_type_id, old_text, new_text)
    problem_type = ProblemType.find_by(id: problem_type_id)
    
    record_operation(
      WorkOrderOperation::OPERATION_TYPE_MODIFY_PROBLEM,
      {
        problem_type_id: problem_type_id,
        problem_type_code: problem_type&.code,
        problem_type_title: problem_type&.title
      },
      { audit_comment: old_text },
      { audit_comment: new_text }
    )
  end
  
  private
  
  # Record an operation
  # @param operation_type [String] The type of operation
  # @param details [Hash] The details of the operation
  # @param previous_state [Hash] The previous state of the work order
  # @param current_state [Hash] The current state of the work order
  # @return [WorkOrderOperation] The created operation record
  def record_operation(operation_type, details, previous_state, current_state)
    WorkOrderOperation.create!(
      work_order: @work_order,
      admin_user: @admin_user,
      operation_type: operation_type,
      details: details.to_json,
      previous_state: previous_state.to_json,
      current_state: current_state.to_json,
      created_at: Time.current
    )
  end
  
  # Get the current state of the work order
  # @return [Hash] The current state of the work order
  def work_order_state
    {
      id: @work_order.id,
      type: @work_order.type,
      status: @work_order.status,
      reimbursement_id: @work_order.reimbursement_id,
      audit_comment: @work_order.audit_comment,
      problem_type_id: @work_order.problem_type_id,
      created_by: @work_order.created_by
    }
  end
end
```

## Service Spec

```ruby
# spec/services/work_order_operation_service_spec.rb
require 'rails_helper'

RSpec.describe WorkOrderOperationService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:work_order) { create(:work_order) }
  let(:service) { described_class.new(work_order, admin_user) }
  
  describe '#record_create' do
    it 'creates a create operation record' do
      expect {
        service.record_create
      }.to change(WorkOrderOperation, :count).by(1)
      
      operation = WorkOrderOperation.last
      expect(operation.work_order).to eq(work_order)
      expect(operation.admin_user).to eq(admin_user)
      expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_CREATE)
      expect(operation.details_hash).to include('message' => '工单已创建')
      expect(operation.previous_state_hash).to be_empty
      expect(operation.current_state_hash).to include(
        'id' => work_order.id,
        'type' => work_order.type,
        'status' => work_order.status
      )
    end
  end
  
  describe '#record_update' do
    it 'returns nil if no attributes changed' do
      expect(service.record_update({})).to be_nil
    end
    
    it 'creates an update operation record with changed attributes' do
      changed_attributes = { 'status' => 'pending', 'audit_comment' => 'old comment' }
      
      allow(work_order).to receive(:status).and_return('approved')
      allow(work_order).to receive(:audit_comment).and_return('new comment')
      
      expect {
        service.record_update(changed_attributes)
      }.to change(WorkOrderOperation, :count).by(1)
      
      operation = WorkOrderOperation.last
      expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_UPDATE)
      expect(operation.details_hash).to include('changed_attributes' => ['status', 'audit_comment'])
      expect(operation.previous_state_hash).to include(
        'status' => 'pending',
        'audit_comment' => 'old comment'
      )
      expect(operation.current_state_hash).to include(
        'status' => 'approved',
        'audit_comment' => 'new comment'
      )
    end
  end
  
  describe '#record_status_change' do
    it 'creates a status change operation record' do
      expect {
        service.record_status_change('pending', 'approved')
      }.to change(WorkOrderOperation, :count).by(1)
      
      operation = WorkOrderOperation.last
      expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_STATUS_CHANGE)
      expect(operation.details_hash).to include(
        'from_status' => 'pending',
        'to_status' => 'approved'
      )
      expect(operation.previous_state_hash).to include('status' => 'pending')
      expect(operation.current_state_hash).to include('status' => 'approved')
    end
  end
  
  describe '#record_add_problem' do
    let(:problem_type) { create(:problem_type, code: '01', title: '问题类型1') }
    
    it 'creates an add problem operation record' do
      allow(work_order).to receive(:audit_comment_was).and_return('')
      allow(work_order).to receive(:audit_comment).and_return('新问题')
      
      expect {
        service.record_add_problem(problem_type.id, '新问题')
      }.to change(WorkOrderOperation, :count).by(1)
      
      operation = WorkOrderOperation.last
      expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_ADD_PROBLEM)
      expect(operation.details_hash).to include(
        'problem_type_id' => problem_type.id,
        'problem_type_code' => problem_type.code,
        'problem_type_title' => problem_type.title
      )
      expect(operation.previous_state_hash).to include('audit_comment' => '')
      expect(operation.current_state_hash).to include('audit_comment' => '新问题')
    end
  end
  
  describe '#record_remove_problem' do
    let(:problem_type) { create(:problem_type, code: '01', title: '问题类型1') }
    
    it 'creates a remove problem operation record' do
      allow(work_order).to receive(:audit_comment_was).and_return('旧问题')
      allow(work_order).to receive(:audit_comment).and_return('')
      
      expect {
        service.record_remove_problem(problem_type.id, '旧问题')
      }.to change(WorkOrderOperation, :count).by(1)
      
      operation = WorkOrderOperation.last
      expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_REMOVE_PROBLEM)
      expect(operation.details_hash).to include(
        'problem_type_id' => problem_type.id,
        'problem_type_code' => problem_type.code,
        'problem_type_title' => problem_type.title
      )
      expect(operation.previous_state_hash).to include('audit_comment' => '旧问题')
      expect(operation.current_state_hash).to include('audit_comment' => '')
    end
  end
  
  describe '#record_modify_problem' do
    let(:problem_type) { create(:problem_type, code: '01', title: '问题类型1') }
    
    it 'creates a modify problem operation record' do
      expect {
        service.record_modify_problem(problem_type.id, '旧问题', '修改后的问题')
      }.to change(WorkOrderOperation, :count).by(1)
      
      operation = WorkOrderOperation.last
      expect(operation.operation_type).to eq(WorkOrderOperation::OPERATION_TYPE_MODIFY_PROBLEM)
      expect(operation.details_hash).to include(
        'problem_type_id' => problem_type.id,
        'problem_type_code' => problem_type.code,
        'problem_type_title' => problem_type.title
      )
      expect(operation.previous_state_hash).to include('audit_comment' => '旧问题')
      expect(operation.current_state_hash).to include('audit_comment' => '修改后的问题')
    end
  end
end
```

## Integration with WorkOrderService

To integrate the `WorkOrderOperationService` with the existing `WorkOrderService`, you need to update the `WorkOrderService` to use the operation service for recording operations:

```ruby
# app/services/work_order_service.rb
class WorkOrderService
  # Existing code...
  
  def initialize(work_order, current_admin_user)
    # Existing code...
    @operation_service = WorkOrderOperationService.new(work_order, current_admin_user)
  end
  
  def create(params = {})
    # Existing creation logic...
    
    if @work_order.save
      # Record creation operation
      @operation_service.record_create
      true
    else
      false
    end
  end
  
  def update(params = {})
    # Save attributes before update
    changed_attributes = {}
    
    # Assign attributes
    assign_shared_attributes(params)
    
    # Check which attributes have changed
    @work_order.changed.each do |attr|
      changed_attributes[attr] = @work_order.send("#{attr}_was")
    end
    
    if @work_order.save
      # Record update operation
      @operation_service.record_update(changed_attributes)
      true
    else
      false
    end
  end
  
  def approve(params = {})
    # Save status before approval
    old_status = @work_order.status
    
    # Existing approval logic...
    
    if @work_order.save
      # Record status change operation
      @operation_service.record_status_change(old_status, @work_order.status)
      true
    else
      false
    end
  end
  
  def reject(params = {})
    # Save status before rejection
    old_status = @work_order.status
    
    # Existing rejection logic...
    
    if @work_order.save
      # Record status change operation
      @operation_service.record_status_change(old_status, @work_order.status)
      true
    else
      false
    end
  end
  
  # Existing code...
end
```

## Integration with WorkOrderProblemService

Similarly, update the `WorkOrderProblemService` to use the operation service for recording problem-related operations:

```ruby
# app/services/work_order_problem_service.rb
class WorkOrderProblemService
  def initialize(work_order, admin_user = nil)
    @work_order = work_order
    @admin_user = admin_user || Current.admin_user
    @operation_service = WorkOrderOperationService.new(work_order, @admin_user)
  end
  
  def add_problem(problem_type_id)
    problem_type = ProblemType.find(problem_type_id)
    
    # Format the problem information
    new_problem_text = format_problem(problem_type)
    
    # Update the work order's audit comment
    current_comment = @work_order.audit_comment.to_s.strip
    
    if current_comment.present?
      # Add a blank line between problems
      @work_order.audit_comment = "#{current_comment}\n\n#{new_problem_text}"
    else
      @work_order.audit_comment = new_problem_text
    end
    
    # Update the problem_type_id field (for reference)
    @work_order.problem_type_id = problem_type_id
    
    # Save the work order
    if @work_order.save
      # Record add problem operation
      @operation_service.record_add_problem(problem_type_id, new_problem_text)
      true
    else
      false
    end
  end
  
  def modify_problem(problem_type_id, new_content)
    problem_type = ProblemType.find(problem_type_id)
    old_content = @work_order.audit_comment.dup
    
    # Update the work order's audit comment
    @work_order.audit_comment = new_content
    
    # Save the work order
    if @work_order.save
      # Record modify problem operation
      @operation_service.record_modify_problem(problem_type_id, old_content, new_content)
      true
    else
      false
    end
  end
  
  def remove_problem(problem_type_id)
    problem_type = ProblemType.find(problem_type_id)
    old_content = @work_order.audit_comment.dup
    
    # Remove the problem from the audit comment
    new_content = remove_problem_from_text(@work_order.audit_comment, problem_type)
    @work_order.audit_comment = new_content
    
    # Save the work order
    if @work_order.save
      # Record remove problem operation
      @operation_service.record_remove_problem(problem_type_id, old_content)
      true
    else
      false
    end
  end
  
  # Existing code...
end
```

## Usage Examples

### Recording Work Order Creation

```ruby
# In a controller
work_order = WorkOrder.new(params[:work_order])
service = WorkOrderService.new(work_order, current_admin_user)
service.create
```

### Recording Work Order Update

```ruby
# In a controller
work_order = WorkOrder.find(params[:id])
service = WorkOrderService.new(work_order, current_admin_user)
service.update(params[:work_order])
```

### Recording Status Change

```ruby
# In a controller
work_order = WorkOrder.find(params[:id])
service = WorkOrderService.new(work_order, current_admin_user)
service.approve(params[:work_order])
```

### Recording Problem Addition

```ruby
# In a controller
work_order = WorkOrder.find(params[:id])
problem_service = WorkOrderProblemService.new(work_order, current_admin_user)
problem_service.add_problem(params[:problem_type_id])
```

### Viewing Operation History

```ruby
# In a controller or view
work_order = WorkOrder.find(params[:id])
operations = work_order.operations.recent_first