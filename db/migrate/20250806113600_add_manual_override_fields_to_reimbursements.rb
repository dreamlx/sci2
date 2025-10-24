class AddManualOverrideFieldsToReimbursements < ActiveRecord::Migration[7.0]
  def change
    add_column :reimbursements, :manual_override, :boolean, default: false, null: false
    add_column :reimbursements, :manual_override_at, :timestamp, null: true
    add_column :reimbursements, :last_external_status, :string, limit: 50, null: true

    add_index :reimbursements, :manual_override
    add_index :reimbursements, :last_external_status
  end
end
