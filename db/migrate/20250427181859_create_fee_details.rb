class CreateFeeDetails < ActiveRecord::Migration[7.1]
  def change
    create_table :fee_details do |t|
      t.string :document_number, null: false, index: true # 关联到 reimbursements.invoice_number
      t.string :fee_type
      t.decimal :amount, precision: 10, scale: 2
      t.string :currency, default: 'CNY'
      t.date :fee_date
      t.string :payment_method
      t.string :verification_status, default: 'pending', null: false, index: true
      t.string :month_belonging
      t.datetime :first_submission_date

      t.timestamps
    end

    # 添加复合索引用于费用明细重复检查
    add_index :fee_details, %i[document_number fee_type amount fee_date],
              name: 'index_fee_details_on_document_and_details',
              unique: true
  end
end
