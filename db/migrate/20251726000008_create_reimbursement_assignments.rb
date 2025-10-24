class CreateReimbursementAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :reimbursement_assignments do |t|
      t.references :reimbursement, null: false, foreign_key: true
      t.references :assignee, null: false, foreign_key: { to_table: :admin_users }
      t.references :assigner, null: false, foreign_key: { to_table: :admin_users }
      t.boolean :is_active, default: true
      t.text :notes
      t.timestamps

      t.index %i[reimbursement_id is_active]
      t.index %i[assignee_id is_active]
    end
  end
end
