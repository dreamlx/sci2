class AddNotificationFieldsToReimbursements < ActiveRecord::Migration[7.1]
  def change
    add_column :reimbursements, :last_viewed_operation_histories_at, :datetime
    add_column :reimbursements, :last_viewed_express_receipts_at, :datetime

    add_index :reimbursements, :last_viewed_operation_histories_at
    add_index :reimbursements, :last_viewed_express_receipts_at
  end
end
