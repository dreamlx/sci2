# WorkOrderProblemService Template

This document provides a template for implementing the updated `WorkOrderProblemService` with problem history tracking functionality.

## Service File

```ruby
# app/services/work_order_problem_service.rb
class WorkOrderProblemService
  def initialize(work_order)
    @work_order = work_order
  end
  
  # Add a problem to the work order
  # @param problem_type_id [Integer] The ID of the problem type to add
  # @param admin_user_id [Integer] The ID of the admin user performing the action (optional)
  # @return [Boolean] Whether the operation was successful
  def add_problem(problem_type_id, admin_user_id = nil)
    problem_type = ProblemType.find(problem_type_id)
    
    # Format the problem information
    new_problem_text = format_problem(problem_type)
    
    # Update the work order's audit comment
    current_comment = @work_order.audit_comment.to_s.strip
    previous_content = current_comment.dup
    
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
      # Record problem history
      record_problem_history(
        'add',
        problem_type_id,
        problem_type.fee_type_id,
        admin_user_id,
        previous_content,
        @work_order.audit_comment
      )
      true
    else
      false
    end
  end
  
  # Modify a problem in the work order
  # @param problem_type_id [Integer] The ID of the problem type to modify
  # @param new_content [String] The new content for the audit comment
  # @param admin_user_id [Integer] The ID of the admin user performing the action (optional)
  # @param change_reason [String] The reason for the change (optional)
  # @return [Boolean] Whether the operation was successful
  def modify_problem(problem_type_id, new_content, admin_user_id = nil, change_reason = nil)
    problem_type = ProblemType.find(problem_type_id)
    previous_content = @work_order.audit_comment.dup
    
    # Update the work order's audit comment
    @work_order.audit_comment = new_content
    
    # Save the work order
    if @work_order.save
      # Record problem history
      record_problem_history(
        'modify',
        problem_type_id,
        problem_type.fee_type_id,
        admin_user_id,
        previous_content,
        new_content,
        change_reason
      )
      true
    else
      false
    end
  end
  
  # Remove a problem from the work order
  # @param problem_type_id [Integer] The ID of the problem type to remove
  # @param admin_user_id [Integer] The ID of the admin user performing the action (optional)
  # @param change_reason [String] The reason for the change (optional)
  # @return [Boolean] Whether the operation was successful
  def remove_problem(problem_type_id, admin_user_id = nil, change_reason = nil)
    problem_type = ProblemType.find(problem_type_id)
    previous_content = @work_order.audit_comment.dup
    
    # Remove the problem from the audit comment
    new_content = remove_problem_from_text(@work_order.audit_comment, problem_type)
    @work_order.audit_comment = new_content
    
    # Save the work order
    if @work_order.save
      # Record problem history
      record_problem_history(
        'remove',
        problem_type_id,
        problem_type.fee_type_id,
        admin_user_id,
        previous_content,
        new_content,
        change_reason
      )
      true
    else
      false
    end
  end
  
  # Clear all problems from the work order
  # @param admin_user_id [Integer] The ID of the admin user performing the action (optional)
  # @param change_reason [String] The reason for the change (optional)
  # @return [Boolean] Whether the operation was successful
  def clear_problems(admin_user_id = nil, change_reason = nil)
    previous_content = @work_order.audit_comment.dup
    
    # Clear the audit comment
    @work_order.audit_comment = nil
    @work_order.problem_type_id = nil
    
    # Save the work order
    if @work_order.save
      # Record problem history
      record_problem_history(
        'remove',
        nil,
        nil,
        admin_user_id,
        previous_content,
        nil,
        change_reason
      )
      true
    else
      false
    end
  end
  
  # Get all problems from the work order's audit comment
  # @return [Array<String>] An array of problem descriptions
  def get_problems
    return [] if @work_order.audit_comment.blank?
    
    # Split the audit comment by double newlines to get individual problems
    @work_order.audit_comment.split("\n\n").map(&:strip).reject(&:blank?)
  end
  
  private
  
  # Format a problem for inclusion in the audit comment
  # @param problem_type [ProblemType] The problem type to format
  # @return [String] The formatted problem text
  def format_problem(problem_type)
    fee_type = problem_type.fee_type
    
    # Format: "费用类型(code+title): 问题类型(code+title)"
    #         "    SOP描述内容"
    #         "    标准处理方法内容"
    [
      "#{fee_type.display_name}: #{problem_type.display_name}",
      "    #{problem_type.sop_description}",
      "    #{problem_type.standard_handling}"
    ].join("\n")
  end
  
  # Record a problem history entry
  # @param action_type [String] The type of action ('add', 'modify', 'remove')
  # @param problem_type_id [Integer] The ID of the problem type
  # @param fee_type_id [Integer] The ID of the fee type
  # @param admin_user_id [Integer] The ID of the admin user performing the action
  # @param previous_content [String] The previous content of the audit comment
  # @param new_content [String] The new content of the audit comment
  # @param change_reason [String] The reason for the change (optional)
  # @return [WorkOrderProblemHistory] The created history entry
  def record_problem_history(action_type, problem_type_id, fee_type_id, admin_user_id, previous_content, new_content, change_reason = nil)
    WorkOrderProblemHistory.create!(
      work_order: @work_order,
      problem_type_id: problem_type_id,
      fee_type_id: fee_type_id,
      admin_user_id: admin_user_id || Current.admin_user&.id,
      action_type: action_type,
      previous_content: previous_content,
      new_content: new_content,
      change_reason: change_reason
    )
  end
  
  # Remove a specific problem from the audit comment text
  # @param text [String] The audit comment text
  # @param problem_type [ProblemType] The problem type to remove
  # @return [String] The text with the problem removed
  def remove_problem_from_text(text, problem_type)
    return text if text.blank?
    
    # This is a simplified implementation that assumes each problem is separated by a blank line
    # A more robust implementation would need to parse the text more carefully
    
    fee_type = problem_type.fee_type
    problem_header = "#{fee_type.display_name}: #{problem_type.display_name}"
    
    # Split the text into problems
    problems = text.split("\n\n")
    
    # Filter out the problem to remove
    filtered_problems = problems.reject do |problem|
      problem.start_with?(problem_header)
    end
    
    # Join the remaining problems back together
    filtered_problems.join("\n\n")
  end
end
```

## Service Spec

```ruby
# spec/services/work_order_problem_service_spec.rb
require 'rails_helper'

RSpec.describe WorkOrderProblemService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:work_order) { create(:work_order) }
  let(:fee_type) { create(:fee_type, code: '01', title: '费用类型1') }
  let(:problem_type) { create(:problem_type, 
                             fee_type: fee_type, 
                             code: '01', 
                             title: '问题类型1', 
                             sop_description: 'SOP描述1', 
                             standard_handling: '标准处理1') }
  
  let(:service) { described_class.new(work_order) }
  
  before do
    allow(Current).to receive(:admin_user).and_return(admin_user)
  end
  
  describe '#add_problem' do
    it 'adds a problem to the work order' do
      expect {
        service.add_problem(problem_type.id)
      }.to change { work_order.reload.audit_comment }
        .from(nil)
        .to("#{fee_type.display_name}: #{problem_type.display_name}\n    #{problem_type.sop_description}\n    #{problem_type.standard_handling}")
        .and change { work_order.problem_type_id }
        .from(nil)
        .to(problem_type.id)
        .and change { WorkOrderProblemHistory.count }.by(1)
      
      history = WorkOrderProblemHistory.last
      expect(history.work_order).to eq(work_order)
      expect(history.problem_type).to eq(problem_type)
      expect(history.fee_type).to eq(fee_type)
      expect(history.admin_user).to eq(admin_user)
      expect(history.action_type).to eq('add')
      expect(history.previous_content).to be_blank
      expect(history.new_content).to eq(work_order.audit_comment)
    end
    
    it 'adds multiple problems with blank lines between them' do
      service.add_problem(problem_type.id)
      
      problem_type2 = create(:problem_type, 
                            fee_type: fee_type, 
                            code: '02', 
                            title: '问题类型2', 
                            sop_description: 'SOP描述2', 
                            standard_handling: '标准处理2')
      
      expect {
        service.add_problem(problem_type2.id)
      }.to change { work_order.reload.audit_comment }
        .and change { WorkOrderProblemHistory.count }.by(1)
      
      expect(work_order.audit_comment).to include(problem_type.display_name)
      expect(work_order.audit_comment).to include(problem_type2.display_name)
      expect(work_order.audit_comment.split("\n\n").size).to eq(2)
    end
  end
  
  describe '#modify_problem' do
    before do
      service.add_problem(problem_type.id)
    end
    
    it 'modifies the problem in the work order' do
      new_content = "Modified content"
      
      expect {
        service.modify_problem(problem_type.id, new_content)
      }.to change { work_order.reload.audit_comment }
        .to(new_content)
        .and change { WorkOrderProblemHistory.count }.by(1)
      
      history = WorkOrderProblemHistory.last
      expect(history.action_type).to eq('modify')
      expect(history.previous_content).to include(problem_type.display_name)
      expect(history.new_content).to eq(new_content)
    end
  end
  
  describe '#remove_problem' do
    before do
      service.add_problem(problem_type.id)
    end
    
    it 'removes the problem from the work order' do
      expect {
        service.remove_problem(problem_type.id)
      }.to change { work_order.reload.audit_comment }
        .to("")
        .and change { WorkOrderProblemHistory.count }.by(1)
      
      history = WorkOrderProblemHistory.last
      expect(history.action_type).to eq('remove')
      expect(history.previous_content).to include(problem_type.display_name)
      expect(history.new_content).to eq("")
    end
    
    it 'removes one problem while keeping others' do
      problem_type2 = create(:problem_type, 
                            fee_type: fee_type, 
                            code: '02', 
                            title: '问题类型2', 
                            sop_description: 'SOP描述2', 
                            standard_handling: '标准处理2')
      
      service.add_problem(problem_type2.id)
      
      expect {
        service.remove_problem(problem_type.id)
      }.to change { work_order.reload.audit_comment }
        .and change { WorkOrderProblemHistory.count }.by(1)
      
      expect(work_order.audit_comment).not_to include(problem_type.display_name)
      expect(work_order.audit_comment).to include(problem_type2.display_name)
    end
  end
  
  describe '#clear_problems' do
    before do
      service.add_problem(problem_type.id)
    end
    
    it 'clears all problems from the work order' do
      expect {
        service.clear_problems
      }.to change { work_order.reload.audit_comment }
        .to(nil)
        .and change { work_order.problem_type_id }
        .to(nil)
        .and change { WorkOrderProblemHistory.count }.by(1)
      
      history = WorkOrderProblemHistory.last
      expect(history.action_type).to eq('remove')
      expect(history.previous_content).to include(problem_type.display_name)
      expect(history.new_content).to be_nil
    end
  end
  
  describe '#get_problems' do
    it 'returns an empty array when there are no problems' do
      expect(service.get_problems).to eq([])
    end
    
    it 'returns an array of problems when there are problems' do
      service.add_problem(problem_type.id)
      
      problem_type2 = create(:problem_type, 
                            fee_type: fee_type, 
                            code: '02', 
                            title: '问题类型2', 
                            sop_description: 'SOP描述2', 
                            standard_handling: '标准处理2')
      
      service.add_problem(problem_type2.id)
      
      problems = service.get_problems
      expect(problems.size).to eq(2)
      expect(problems[0]).to include(problem_type.display_name)
      expect(problems[1]).to include(problem_type2.display_name)
    end
  end
end
```

## Usage Examples

### Adding a Problem

```ruby
# In a controller
work_order = WorkOrder.find(params[:id])
service = WorkOrderProblemService.new(work_order)
service.add_problem(params[:problem_type_id], current_admin_user.id)
```

### Modifying a Problem

```ruby
# In a controller
work_order = WorkOrder.find(params[:id])
service = WorkOrderProblemService.new(work_order)
service.modify_problem(params[:problem_type_id], params[:new_content], current_admin_user.id, params[:change_reason])
```

### Removing a Problem

```ruby
# In a controller
work_order = WorkOrder.find(params[:id])
service = WorkOrderProblemService.new(work_order)
service.remove_problem(params[:problem_type_id], current_admin_user.id, params[:change_reason])
```

### Getting Problems

```ruby
# In a controller or view
work_order = WorkOrder.find(params[:id])
service = WorkOrderProblemService.new(work_order)
problems = service.get_problems
```

### Viewing Problem History

```ruby
# In a controller or view
work_order = WorkOrder.find(params[:id])
histories = work_order.problem_histories.recent_first