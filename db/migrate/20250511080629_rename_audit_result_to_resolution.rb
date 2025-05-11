class RenameAuditResultToResolution < ActiveRecord::Migration[7.1]
  def change
    rename_column :work_orders, :audit_result, :resolution
  end
end
