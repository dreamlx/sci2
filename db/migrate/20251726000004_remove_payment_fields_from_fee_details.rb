class RemovePaymentFieldsFromFeeDetails < ActiveRecord::Migration[7.1]
  def change
    remove_column :fee_details, :payment_method, :string, if_exists: true
    remove_column :fee_details, :currency, :string, default: 'CNY', if_exists: true
  end
end
