class CreateReimbursements < ActiveRecord::Migration[7.1]
  def change
    create_table :reimbursements do |t|
      t.string :invoice_number, null: false
      t.string :document_name
      t.string :applicant
      t.string :applicant_id
      t.string :company
      t.string :department
      t.decimal :amount, precision: 10, scale: 2
      t.string :receipt_status, default: 'pending'
      t.string :reimbursement_status, default: 'pending'
      t.datetime :receipt_date
      t.datetime :submission_date
      t.boolean :is_electronic, default: false
      t.boolean :is_complete, default: false
      
      t.timestamps
    end
    
    add_index :reimbursements, :invoice_number, unique: true
    add_index :reimbursements, :applicant
    add_index :reimbursements, :receipt_status
    add_index :reimbursements, :reimbursement_status
    add_index :reimbursements, :is_complete
  end
end
