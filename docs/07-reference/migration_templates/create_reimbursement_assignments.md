# Migration Template: Create Reimbursement Assignments

This document provides a template for creating the `reimbursement_assignments` table migration.

## Migration File

```ruby
class CreateReimbursementAssignments < ActiveRecord::Migration[7.0]
  def change
    create_table :reimbursement_assignments do |t|
      t.references :reimbursement, null: false, foreign_key: true
      t.references :assignee, null: false, foreign_key: { to_table: :admin_users }
      t.references :assigner, null: false, foreign_key: { to_table: :admin_users }
      t.boolean :is_active, default: true
      t.text :notes
      t.timestamps
      
      t.index [:reimbursement_id, :is_active]
      t.index [:assignee_id, :is_active]
    end
  end
end
```

## Migration File Path

Save this migration file as:
```
db/migrate/YYYYMMDDHHMMSS_create_reimbursement_assignments.rb
```

Replace `YYYYMMDDHHMMSS` with the current timestamp.

## Model Implementation

After running the migration, implement the model:

```ruby
# app/models/reimbursement_assignment.rb
class ReimbursementAssignment < ApplicationRecord
  belongs_to :reimbursement
  belongs_to :assignee, class_name: 'AdminUser'
  belongs_to :assigner, class_name: 'AdminUser'
  
  validates :reimbursement_id, uniqueness: { scope: :is_active, message: "已经有一个活跃的分配" }, if: :is_active?
  
  scope :active, -> { where(is_active: true) }
  scope :by_assignee, ->(assignee_id) { where(assignee_id: assignee_id) }
  scope :by_assigner, ->(assigner_id) { where(assigner_id: assigner_id) }
  scope :recent_first, -> { order(created_at: :desc) }
  
  before_create :deactivate_previous_assignments
  
  private
  
  def deactivate_previous_assignments
    if is_active?
      ReimbursementAssignment.where(reimbursement_id: reimbursement_id, is_active: true)
                            .update_all(is_active: false)
    end
  end
end
```

## Model Associations

Update the related models to include the associations:

```ruby
# app/models/reimbursement.rb
has_many :assignments, class_name: 'ReimbursementAssignment', dependent: :destroy
has_many :assignees, through: :assignments, source: :assignee
has_one :active_assignment, -> { where(is_active: true) }, class_name: 'ReimbursementAssignment'
has_one :current_assignee, through: :active_assignment, source: :assignee

# app/models/admin_user.rb
has_many :assigned_reimbursements, class_name: 'ReimbursementAssignment', foreign_key: 'assignee_id'
has_many :active_assigned_reimbursements, -> { where(is_active: true) }, class_name: 'ReimbursementAssignment', foreign_key: 'assignee_id'
has_many :reimbursements_to_process, through: :active_assigned_reimbursements, source: :reimbursement
has_many :reimbursement_assignments_made, class_name: 'ReimbursementAssignment', foreign_key: 'assigner_id'
```

## Factory for Testing

```ruby
# spec/factories/reimbursement_assignments.rb
FactoryBot.define do
  factory :reimbursement_assignment do
    association :reimbursement
    association :assignee, factory: :admin_user
    association :assigner, factory: :admin_user
    is_active { true }
    notes { "Test assignment notes" }
  end
end
```

## Model Spec

```ruby
# spec/models/reimbursement_assignment_spec.rb
require 'rails_helper'

RSpec.describe ReimbursementAssignment, type: :model do
  describe 'associations' do
    it { should belong_to(:reimbursement) }
    it { should belong_to(:assignee).class_name('AdminUser') }
    it { should belong_to(:assigner).class_name('AdminUser') }
  end
  
  describe 'validations' do
    it 'validates uniqueness of reimbursement_id scoped to is_active when is_active is true' do
      reimbursement = create(:reimbursement)
      create(:reimbursement_assignment, reimbursement: reimbursement, is_active: true)
      
      new_assignment = build(:reimbursement_assignment, reimbursement: reimbursement, is_active: true)
      expect(new_assignment).not_to be_valid
      expect(new_assignment.errors[:reimbursement_id]).to include("已经有一个活跃的分配")
    end
    
    it 'allows multiple inactive assignments for the same reimbursement' do
      reimbursement = create(:reimbursement)
      create(:reimbursement_assignment, reimbursement: reimbursement, is_active: false)
      
      new_assignment = build(:reimbursement_assignment, reimbursement: reimbursement, is_active: false)
      expect(new_assignment).to be_valid
    end
    
    it 'allows multiple active assignments for different reimbursements' do
      create(:reimbursement_assignment, is_active: true)
      
      new_assignment = build(:reimbursement_assignment, is_active: true)
      expect(new_assignment).to be_valid
    end
  end
  
  describe 'scopes' do
    let!(:active_assignment) { create(:reimbursement_assignment, is_active: true) }
    let!(:inactive_assignment) { create(:reimbursement_assignment, is_active: false) }
    let!(:assignee) { create(:admin_user) }
    let!(:assigner) { create(:admin_user) }
    let!(:assignment_by_assignee) { create(:reimbursement_assignment, assignee: assignee) }
    let!(:assignment_by_assigner) { create(:reimbursement_assignment, assigner: assigner) }
    
    it 'active scope returns only active assignments' do
      expect(ReimbursementAssignment.active).to include(active_assignment)
      expect(ReimbursementAssignment.active).not_to include(inactive_assignment)
    end
    
    it 'by_assignee scope returns assignments for the specified assignee' do
      expect(ReimbursementAssignment.by_assignee(assignee.id)).to include(assignment_by_assignee)
      expect(ReimbursementAssignment.by_assignee(assignee.id)).not_to include(assignment_by_assigner)
    end
    
    it 'by_assigner scope returns assignments made by the specified assigner' do
      expect(ReimbursementAssignment.by_assigner(assigner.id)).to include(assignment_by_assigner)
      expect(ReimbursementAssignment.by_assigner(assigner.id)).not_to include(assignment_by_assignee)
    end
    
    it 'recent_first scope orders assignments by created_at in descending order' do
      old_assignment = create(:reimbursement_assignment, created_at: 2.days.ago)
      new_assignment = create(:reimbursement_assignment, created_at: 1.day.ago)
      
      expect(ReimbursementAssignment.recent_first.first).to eq(new_assignment)
      expect(ReimbursementAssignment.recent_first.last).to eq(old_assignment)
    end
  end
  
  describe 'callbacks' do
    it 'deactivates previous active assignments for the same reimbursement' do
      reimbursement = create(:reimbursement)
      old_assignment = create(:reimbursement_assignment, reimbursement: reimbursement, is_active: true)
      
      new_assignment = create(:reimbursement_assignment, reimbursement: reimbursement, is_active: true)
      
      expect(old_assignment.reload.is_active).to be_falsey
      expect(new_assignment.is_active).to be_truthy
    end
    
    it 'does not deactivate active assignments for other reimbursements' do
      other_assignment = create(:reimbursement_assignment, is_active: true)
      
      create(:reimbursement_assignment, is_active: true)
      
      expect(other_assignment.reload.is_active).to be_truthy
    end
    
    it 'does not deactivate previous assignments when creating an inactive assignment' do
      reimbursement = create(:reimbursement)
      old_assignment = create(:reimbursement_assignment, reimbursement: reimbursement, is_active: true)
      
      create(:reimbursement_assignment, reimbursement: reimbursement, is_active: false)
      
      expect(old_assignment.reload.is_active).to be_truthy
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