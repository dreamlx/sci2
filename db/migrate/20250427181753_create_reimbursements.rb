class CreateReimbursements < ActiveRecord::Migration[7.1]
  def change
    create_table :reimbursements do |t|
      t.string :invoice_number, null: false, index: { unique: true }
      t.string :document_name
      t.string :applicant
      t.string :applicant_id
      t.string :company
      t.string :department
      t.string :receipt_status
      t.datetime :receipt_date
      t.datetime :submission_date
      t.decimal :amount, precision: 10, scale: 2
      t.boolean :is_electronic, default: false, null: false
      t.string :status, default: 'pending', null: false, index: true
      t.string :external_status # 存储原始外部状态
      t.datetime :approval_date
      t.string :approver_name
      t.string :related_application_number
      t.date :accounting_date
      t.string :document_tags

      t.timestamps
    end
  end
end
