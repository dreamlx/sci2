# Migration Template: Create Work Order Problem Histories

This document provides a template for creating the `work_order_problem_histories` table migration.

## Migration File

```ruby
class CreateWorkOrderProblemHistories < ActiveRecord::Migration[7.0]
  def change
    create_table :work_order_problem_histories do |t|
      t.references :work_order, null: false, foreign_key: true
      t.references :problem_type, null: true, foreign_key: true
      t.references :fee_type, null: true, foreign_key: true
      t.references :admin_user, null: false, foreign_key: true
      t.string :action_type, null: false # 'add', 'modify', 'remove'
      t.text :previous_content
      t.text :new_content
      t.text :change_reason
      t.datetime :created_at, null: false
      
      t.index [:work_order_id, :created_at]
    end
  end
end
```

## Migration File Path

Save this migration file as:
```
db/migrate/YYYYMMDDHHMMSS_create_work_order_problem_histories.rb
```

Replace `YYYYMMDDHHMMSS` with the current timestamp.

## Model Implementation

After running the migration, implement the model:

```ruby
# app/models/work_order_problem_history.rb
class WorkOrderProblemHistory < ApplicationRecord
  belongs_to :work_order
  belongs_to :problem_type, optional: true
  belongs_to :fee_type, optional: true
  belongs_to :admin_user
  
  validates :action_type, presence: true, inclusion: { in: ['add', 'modify', 'remove'] }
  
  scope :by_work_order, ->(work_order_id) { where(work_order_id: work_order_id) }
  scope :by_admin_user, ->(admin_user_id) { where(admin_user_id: admin_user_id) }
  scope :by_action_type, ->(action_type) { where(action_type: action_type) }
  scope :recent_first, -> { order(created_at: :desc) }
end
```

## Model Associations

Update the related models to include the associations:

```ruby
# app/models/work_order.rb
has_many :problem_histories, class_name: 'WorkOrderProblemHistory', dependent: :destroy

# app/models/problem_type.rb
has_many :problem_histories, class_name: 'WorkOrderProblemHistory', dependent: :nullify

# app/models/fee_type.rb
has_many :problem_histories, class_name: 'WorkOrderProblemHistory', dependent: :nullify

# app/models/admin_user.rb
has_many :problem_histories, class_name: 'WorkOrderProblemHistory', dependent: :nullify
```

## Running the Migration

To run the migration:

```bash
rails db:migrate
```

To rollback the migration:

```bash
rails db:rollback