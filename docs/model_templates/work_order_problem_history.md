# WorkOrderProblemHistory Model Template

This document provides a template for implementing the `WorkOrderProblemHistory` model.

## Model File

```ruby
# app/models/work_order_problem_history.rb
class WorkOrderProblemHistory < ApplicationRecord
  # Associations
  belongs_to :work_order
  belongs_to :problem_type, optional: true
  belongs_to :fee_type, optional: true
  belongs_to :admin_user
  
  # Validations
  validates :action_type, presence: true, inclusion: { in: ['add', 'modify', 'remove'] }
  
  # Scopes
  scope :by_work_order, ->(work_order_id) { where(work_order_id: work_order_id) }
  scope :by_admin_user, ->(admin_user_id) { where(admin_user_id: admin_user_id) }
  scope :by_action_type, ->(action_type) { where(action_type: action_type) }
  scope :recent_first, -> { order(created_at: :desc) }
  
  # Class methods
  def self.ransackable_attributes(auth_object = nil)
    %w[id work_order_id problem_type_id fee_type_id admin_user_id action_type 
       previous_content new_content change_reason created_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[work_order problem_type fee_type admin_user]
  end
  
  # Instance methods
  
  # Returns a formatted representation of the action type
  def action_type_display
    case action_type
    when 'add'
      '添加'
    when 'modify'
      '修改'
    when 'remove'
      '移除'
    else
      action_type
    end
  end
  
  # Returns a diff between previous_content and new_content
  def content_diff
    return nil if previous_content.blank? || new_content.blank?
    
    # This is a placeholder for a diff implementation
    # In a real implementation, you would use a diff library like Diffy
    # Example: Diffy::Diff.new(previous_content, new_content, context: 2).to_s(:html)
    "Diff between previous and new content"
  end
end
```

## Model Associations in Related Models

Update the related models to include the associations:

```ruby
# app/models/work_order.rb
class WorkOrder < ApplicationRecord
  # Existing code...
  
  has_many :problem_histories, class_name: 'WorkOrderProblemHistory', dependent: :destroy
  
  # Existing code...
end

# app/models/problem_type.rb
class ProblemType < ApplicationRecord
  # Existing code...
  
  has_many :problem_histories, class_name: 'WorkOrderProblemHistory', dependent: :nullify
  
  # Existing code...
end

# app/models/fee_type.rb
class FeeType < ApplicationRecord
  # Existing code...
  
  has_many :problem_histories, class_name: 'WorkOrderProblemHistory', dependent: :nullify
  
  # Existing code...
end

# app/models/admin_user.rb
class AdminUser < ApplicationRecord
  # Existing code...
  
  has_many :problem_histories, class_name: 'WorkOrderProblemHistory', dependent: :nullify
  
  # Existing code...
end
```

## Factory for Testing

```ruby
# spec/factories/work_order_problem_histories.rb
FactoryBot.define do
  factory :work_order_problem_history do
    association :work_order
    association :problem_type
    association :fee_type
    association :admin_user
    action_type { ['add', 'modify', 'remove'].sample }
    previous_content { "Previous content example" }
    new_content { "New content example" }
    change_reason { "Change reason example" }
    created_at { Time.current }
  end
end
```

## Model Spec

```ruby
# spec/models/work_order_problem_history_spec.rb
require 'rails_helper'

RSpec.describe WorkOrderProblemHistory, type: :model do
  describe 'associations' do
    it { should belong_to(:work_order) }
    it { should belong_to(:problem_type).optional }
    it { should belong_to(:fee_type).optional }
    it { should belong_to(:admin_user) }
  end
  
  describe 'validations' do
    it { should validate_presence_of(:action_type) }
    it { should validate_inclusion_of(:action_type).in_array(['add', 'modify', 'remove']) }
  end
  
  describe 'scopes' do
    let!(:work_order) { create(:work_order) }
    let!(:admin_user) { create(:admin_user) }
    let!(:history1) { create(:work_order_problem_history, work_order: work_order, admin_user: admin_user, action_type: 'add', created_at: 1.day.ago) }
    let!(:history2) { create(:work_order_problem_history, work_order: work_order, admin_user: admin_user, action_type: 'modify', created_at: 2.days.ago) }
    let!(:history3) { create(:work_order_problem_history, action_type: 'remove', created_at: 3.days.ago) }
    
    it 'filters by work_order_id' do
      expect(WorkOrderProblemHistory.by_work_order(work_order.id)).to match_array([history1, history2])
    end
    
    it 'filters by admin_user_id' do
      expect(WorkOrderProblemHistory.by_admin_user(admin_user.id)).to match_array([history1, history2])
    end
    
    it 'filters by action_type' do
      expect(WorkOrderProblemHistory.by_action_type('add')).to match_array([history1])
      expect(WorkOrderProblemHistory.by_action_type('modify')).to match_array([history2])
      expect(WorkOrderProblemHistory.by_action_type('remove')).to match_array([history3])
    end
    
    it 'orders by created_at desc' do
      expect(WorkOrderProblemHistory.recent_first).to eq([history1, history2, history3])
    end
  end
  
  describe '#action_type_display' do
    it 'returns the Chinese translation of the action type' do
      history = build(:work_order_problem_history, action_type: 'add')
      expect(history.action_type_display).to eq('添加')
      
      history.action_type = 'modify'
      expect(history.action_type_display).to eq('修改')
      
      history.action_type = 'remove'
      expect(history.action_type_display).to eq('移除')
    end
  end
  
  describe '#content_diff' do
    it 'returns nil if previous_content or new_content is blank' do
      history = build(:work_order_problem_history, previous_content: nil, new_content: 'New content')
      expect(history.content_diff).to be_nil
      
      history.previous_content = 'Previous content'
      history.new_content = nil
      expect(history.content_diff).to be_nil
    end
    
    it 'returns a diff between previous_content and new_content' do
      history = build(:work_order_problem_history, 
                      previous_content: 'Previous content', 
                      new_content: 'New content')
      expect(history.content_diff).to be_a(String)
    end
  end
end