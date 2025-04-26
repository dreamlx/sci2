class CreateFeeDetailSelections < ActiveRecord::Migration[7.1]
  def change
    create_table :fee_detail_selections do |t|
      t.references :fee_detail, foreign_key: true
      t.references :audit_work_order, foreign_key: true, null: true
      t.references :communication_work_order, foreign_key: true, null: true
      t.string :verification_status
      t.text :verification_comment
      t.integer :verified_by
      t.datetime :verified_at
      
      t.timestamps
    end
    
    add_index :fee_detail_selections, [:fee_detail_id, :audit_work_order_id], 
              unique: true, 
              name: 'index_fee_detail_selections_on_fee_detail_and_audit_work_order',
              where: 'audit_work_order_id IS NOT NULL'
              
    add_index :fee_detail_selections, [:fee_detail_id, :communication_work_order_id], 
              unique: true, 
              name: 'index_fee_detail_selections_on_fee_detail_and_comm_work_order',
              where: 'communication_work_order_id IS NOT NULL'
  end
end
