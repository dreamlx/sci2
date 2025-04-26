class CreateExpressReceiptWorkOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :express_receipt_work_orders do |t|
      t.references :reimbursement, foreign_key: true
      t.string :status, null: false
      t.string :tracking_number
      t.datetime :received_at
      t.string :courier_name
      t.integer :created_by
      
      t.timestamps
    end
    
    add_index :express_receipt_work_orders, :status
    add_index :express_receipt_work_orders, :tracking_number
  end
end
