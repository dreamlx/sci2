class CreateCommunicationWorkOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :communication_work_orders do |t|
      t.references :reimbursement, foreign_key: true
      t.references :audit_work_order, foreign_key: true
      t.string :status, null: false
      t.string :communication_method
      t.string :initiator_role
      t.text :resolution_summary
      t.integer :created_by
      
      t.timestamps
    end
    
    add_index :communication_work_orders, :status
  end
end
