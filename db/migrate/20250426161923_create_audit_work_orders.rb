class CreateAuditWorkOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_work_orders do |t|
      t.references :reimbursement, foreign_key: true
      t.references :express_receipt_work_order, foreign_key: true, null: true
      t.string :status, null: false
      t.string :audit_result
      t.text :audit_comment
      t.datetime :audit_date
      t.boolean :vat_verified
      t.integer :created_by
      
      t.timestamps
    end
    
    add_index :audit_work_orders, :status
    add_index :audit_work_orders, :audit_result
  end
end
