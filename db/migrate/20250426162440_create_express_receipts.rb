class CreateExpressReceipts < ActiveRecord::Migration[7.1]
  def change
    create_table :express_receipts do |t|
      t.string :document_number, null: false
      t.string :tracking_number
      t.datetime :receive_date
      t.string :receiver
      t.string :courier_company
      
      t.timestamps
    end
    
    add_index :express_receipts, :document_number
    add_index :express_receipts, :tracking_number
  end
end
