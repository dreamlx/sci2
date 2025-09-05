class AddUnifiedNotificationFieldsToReimbursements < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:reimbursements, :last_viewed_at)
      add_column :reimbursements, :last_viewed_at, :datetime
    end

    unless column_exists?(:reimbursements, :last_update_at)
      add_column :reimbursements, :last_update_at, :datetime
    end

    unless column_exists?(:reimbursements, :has_updates)
      add_column :reimbursements, :has_updates, :boolean, default: false, null: false
    end
  end
end
