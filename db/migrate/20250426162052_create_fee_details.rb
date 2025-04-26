class CreateFeeDetails < ActiveRecord::Migration[7.1]
  def change
    create_table :fee_details do |t|
      t.string :document_number, null: false
      t.string :fee_type
      t.decimal :amount, precision: 10, scale: 2
      t.string :currency, default: 'CNY'
      t.datetime :fee_date
      t.string :payment_method
      t.string :verification_status, default: 'pending'
      
      t.timestamps
    end
    
    add_index :fee_details, :document_number
    add_index :fee_details, :verification_status
  end
end
