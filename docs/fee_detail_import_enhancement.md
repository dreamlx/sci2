# Fee Detail Import Enhancement

## Overview

This document provides detailed implementation instructions for enhancing the fee detail import functionality to allow updating reimbursement numbers for existing fee details.

## Problem Statement

The current system prevents updating a fee detail's reimbursement number during import if it already exists with a different number. This causes errors like:

```
导入失败: 行 157134 (费用ID: 1940724831490297857): 该费用ID已存在于系统中，但关联的报销单号不匹配。现有报销单号: ER22790247, 导入报销单号: ER22981847
```

From a business perspective, users sometimes need to correct reimbursement numbers due to operational errors, so this restriction should be removed.

## Solution

Modify the import process to:

1. **Allow Reimbursement Number Updates**: When a fee detail exists with a different reimbursement number, update it instead of showing an error
2. **Validate New Reimbursement**: Ensure the new reimbursement number exists in the system
3. **Update Both Reimbursements**: Update the status of both the old and new reimbursements
4. **Track Changes**: Keep track of these updates for reporting purposes
5. **Update UI**: Modify the import instructions and success messages to reflect this new behavior

## Files to Modify

1. `app/services/fee_detail_import_service.rb`
2. `app/admin/fee_details.rb`

## Detailed Code Changes

### 1. Modify `app/services/fee_detail_import_service.rb`

#### A. Update the `initialize` method

Add initialization for tracking reimbursement number updates:

```ruby
def initialize(file, current_admin_user)
  @file = file
  @current_admin_user = current_admin_user
  @created_count = 0
  @updated_count = 0
  @skipped_due_to_error_count = 0
  @unmatched_reimbursement_count = 0
  @unmatched_reimbursement_details = []
  @errors = []
  @reimbursement_number_updated_count = 0  # Add this line
  @reimbursement_number_updates = []       # Add this line
end
```

#### B. Update the `import_fee_detail` method

Replace the current reimbursement number mismatch check (lines 98-102) with:

```ruby
# 检查现有费用明细是否具有不同的document_number
if existing_fee_detail && existing_fee_detail.document_number != document_number
  # Check if the new reimbursement exists
  new_reimbursement = Reimbursement.find_by(invoice_number: document_number)
  unless new_reimbursement
    @skipped_due_to_error_count += 1
    @errors << "行 #{row_number} (费用ID: #{external_id}): 无法更新报销单号，新的报销单号 #{document_number} 不存在于系统中"
    return
  end
  
  # Store the old reimbursement for status update
  old_reimbursement = Reimbursement.find_by(invoice_number: existing_fee_detail.document_number)
  
  # Track this change for reporting
  @reimbursement_number_updated_count += 1
  @reimbursement_number_updates << {
    row: row_number,
    fee_id: external_id,
    old_number: existing_fee_detail.document_number,
    new_number: document_number
  }
  
  # Continue with the update (the document_number will be updated in the attributes assignment below)
end
```

#### C. Add code to update the old reimbursement's status

After line 141 (after `reimbursement.update_status_based_on_fee_details!`), add:

```ruby
# Update status of old reimbursement if we changed the document_number
if existing_fee_detail && existing_fee_detail.document_number != document_number && defined?(old_reimbursement) && old_reimbursement
  # Update status of old reimbursement since a fee detail was removed
  old_reimbursement.update_status_based_on_fee_details!
end
```

#### D. Update the result hash in the `import` method

Modify the result hash around line 50 to include information about reimbursement number updates:

```ruby
{
  success: @errors.empty?,
  created: @created_count,
  updated: @updated_count,
  reimbursement_number_updated: @reimbursement_number_updated_count,  # Add this line
  unmatched_reimbursement: @unmatched_reimbursement_count,
  skipped_errors: @skipped_due_to_error_count,
  error_details: error_summary,
  unmatched_count: @unmatched_reimbursement_details.size
}
```

### 2. Modify `app/admin/fee_details.rb`

#### A. Update the import instructions

Update the instructions array in the `new_import` action (around line 34):

```ruby
instructions: [
  "请上传CSV格式文件",
  "文件必须包含以下列：报销单号,费用id,费用类型,原始金额,费用发生日期",
  "其他有用字段：所属月,首次提交日期,计划/预申请,产品,弹性字段6,弹性字段7,费用对应计划,费用关联申请单,备注",
  "系统会根据报销单号关联到已存在的报销单",
  "如果费用明细已存在（根据费用id判断）且报销单号相同，将更新现有记录",
  "如果费用明细已存在但报销单号不同，将更新费用明细的报销单号（前提是新报销单号存在于系统中）",  # Update this line
  "如果费用明细不存在，将创建新记录"
]
```

#### B. Update the success message

Update the notice_message in the `import` action (around line 56):

```ruby
notice_message = "导入成功: #{result[:created]} 创建, #{result[:updated]} 更新."
notice_message += " #{result[:reimbursement_number_updated]} 报销单号已更新." if result[:reimbursement_number_updated].to_i > 0  # Add this line
notice_message += " #{result[:skipped_errors]} 错误." if result[:skipped_errors].to_i > 0
notice_message += " #{result[:unmatched_count]} 未匹配的报销单." if result[:unmatched_count].to_i > 0
```

## Testing Instructions

### Unit Tests

Create or update unit tests for the `FeeDetailImportService` to cover:

1. Importing a fee detail with an existing fee ID but different reimbursement number
2. Importing a fee detail with an existing fee ID but different reimbursement number that doesn't exist
3. Verifying both old and new reimbursements have their statuses updated correctly

### Manual Testing

1. Prepare test CSV files with:
   - New fee details
   - Existing fee details with the same reimbursement number
   - Existing fee details with a different reimbursement number
   - Existing fee details with a different reimbursement number that doesn't exist

2. Test the import functionality through the admin interface:
   - Verify the success messages and error messages are displayed correctly
   - Verify the database records are updated correctly
   - Verify the reimbursement statuses are updated correctly

## Deployment Notes

1. This change modifies the behavior of the fee detail import process, allowing reimbursement numbers to be updated.
2. Ensure users are aware of this change in behavior.
3. Monitor the system after deployment to ensure there are no unexpected issues.