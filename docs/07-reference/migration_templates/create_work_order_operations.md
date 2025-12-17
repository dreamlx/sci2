# Migration Template: Create Work Order Operations

This document provides a template for creating the `work_order_operations` table migration.

## Migration File

```ruby
class CreateWorkOrderOperations < ActiveRecord::Migration[7.0]
  def change
    create_table :work_order_operations do |t|
      t.references :work_order, null: false, foreign_key: true
      t.references :admin_user, null: false, foreign_key: true
      t.string :operation_type, null: false # 'create', 'update', 'status_change', 'add_problem', 'remove_problem', etc.
      t.text :details # JSON格式，存储操作的详细信息
      t.text :previous_state # JSON格式，存储操作前的状态
      t.text :current_state # JSON格式，存储操作后的状态
      t.datetime :created_at, null: false
      
      t.index [:work_order_id, :created_at]
      t.index [:admin_user_id, :created_at]
      t.index [:operation_type, :created_at]
    end
  end
end
```

## Migration File Path

Save this migration file as:
```
db/migrate/YYYYMMDDHHMMSS_create_work_order_operations.rb
```

Replace `YYYYMMDDHHMMSS` with the current timestamp.

## Model Implementation

After running the migration, implement the model:

```ruby
# app/models/work_order_operation.rb
class WorkOrderOperation < ApplicationRecord
  belongs_to :work_order
  belongs_to :admin_user
  
  validates :operation_type, presence: true
  
  scope :by_work_order, ->(work_order_id) { where(work_order_id: work_order_id) }
  scope :by_admin_user, ->(admin_user_id) { where(admin_user_id: admin_user_id) }
  scope :by_operation_type, ->(operation_type) { where(operation_type: operation_type) }
  scope :recent_first, -> { order(created_at: :desc) }
  
  # 操作类型常量
  OPERATION_TYPE_CREATE = 'create'.freeze
  OPERATION_TYPE_UPDATE = 'update'.freeze
  OPERATION_TYPE_STATUS_CHANGE = 'status_change'.freeze
  OPERATION_TYPE_ADD_PROBLEM = 'add_problem'.freeze
  OPERATION_TYPE_REMOVE_PROBLEM = 'remove_problem'.freeze
  OPERATION_TYPE_MODIFY_PROBLEM = 'modify_problem'.freeze
  
  # 操作类型列表
  def self.operation_types
    [
      OPERATION_TYPE_CREATE,
      OPERATION_TYPE_UPDATE,
      OPERATION_TYPE_STATUS_CHANGE,
      OPERATION_TYPE_ADD_PROBLEM,
      OPERATION_TYPE_REMOVE_PROBLEM,
      OPERATION_TYPE_MODIFY_PROBLEM
    ]
  end
  
  # 获取操作类型的显示名称
  def operation_type_display
    case operation_type
    when OPERATION_TYPE_CREATE
      '创建工单'
    when OPERATION_TYPE_UPDATE
      '更新工单'
    when OPERATION_TYPE_STATUS_CHANGE
      '状态变更'
    when OPERATION_TYPE_ADD_PROBLEM
      '添加问题'
    when OPERATION_TYPE_REMOVE_PROBLEM
      '移除问题'
    when OPERATION_TYPE_MODIFY_PROBLEM
      '修改问题'
    else
      operation_type
    end
  end
  
  # 获取操作详情的哈希表示
  def details_hash
    return {} if details.blank?
    
    begin
      JSON.parse(details)
    rescue JSON::ParserError
      {}
    end
  end
  
  # 获取操作前状态的哈希表示
  def previous_state_hash
    return {} if previous_state.blank?
    
    begin
      JSON.parse(previous_state)
    rescue JSON::ParserError
      {}
    end
  end
  
  # 获取操作后状态的哈希表示
  def current_state_hash
    return {} if current_state.blank?
    
    begin
      JSON.parse(current_state)
    rescue JSON::ParserError
      {}
    end
  end
end
```

## Model Associations

Update the related models to include the associations:

```ruby
# app/models/work_order.rb
has_many :operations, class_name: 'WorkOrderOperation', dependent: :destroy

# app/models/admin_user.rb
has_many :work_order_operations, dependent: :nullify
```

## Factory for Testing

```ruby
# spec/factories/work_order_operations.rb
FactoryBot.define do
  factory :work_order_operation do
    association :work_order
    association :admin_user
    operation_type { WorkOrderOperation.operation_types.sample }
    details { { message: "Test operation details" }.to_json }
    previous_state { { status: "pending" }.to_json }
    current_state { { status: "approved" }.to_json }
    created_at { Time.current }
  end
end
```

## Model Spec

```ruby
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
    let!(:work_order) { create(:work_order) }
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
      operation = build(:work_order_operation, operation_type: 'create')
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
    let(:operation) { build(:work_order_operation) }
    
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
```

## Running the Migration

To run the migration:

```bash
rails db:migrate
```

To rollback the migration:

```bash
rails db:rollback