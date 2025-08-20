# Reimbursement Assignment Display Fix

## Problem
The dashboard shows unassigned reimbursements for the current day using:
```ruby
Reimbursement.left_joins(:active_assignment)
            .where(reimbursement_assignments: { id: nil })
            .where(created_at: Date.current.beginning_of_day..Date.current.end_of_day)
```

## Solution
1. Add `unassigned` scope to Reimbursement model:
```ruby
scope :unassigned, -> { 
  left_joins(:active_assignment)
    .where(reimbursement_assignments: { id: nil }) 
}
```

2. Update dashboard to use the new scope:
```ruby
panel "今日未分配的报销单" do
  table_for Reimbursement.unassigned
                        .where(created_at: Date.current.beginning_of_day..Date.current.end_of_day)
                        .order(created_at: :desc)
                        .limit(10) do
    # ... existing columns ...
  end
end
```

## Implementation Steps
1. Switch to Code mode
2. Add the scope to `app/models/reimbursement.rb`
3. Update `app/admin/dashboard.rb`
4. Test changes in development