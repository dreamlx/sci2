class AddDefaultStatusToExpressReceiptWorkOrders < ActiveRecord::Migration[7.1]
  def change
    change_column_default :express_receipt_work_orders, :status, from: nil, to: 'received'
  end
end