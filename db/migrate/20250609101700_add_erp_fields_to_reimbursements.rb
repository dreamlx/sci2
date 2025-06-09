class AddErpFieldsToReimbursements < ActiveRecord::Migration[7.1]
  def change
    add_column :reimbursements, :erp_current_approval_node, :string
    add_column :reimbursements, :erp_current_approver, :string
    add_column :reimbursements, :erp_flexible_field_2, :string
    add_column :reimbursements, :erp_node_entry_time, :datetime
    add_column :reimbursements, :erp_first_submitted_at, :datetime
    add_column :reimbursements, :erp_flexible_field_8, :string
  end
end