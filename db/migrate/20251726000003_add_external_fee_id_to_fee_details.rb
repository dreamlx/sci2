class AddExternalFeeIdToFeeDetails < ActiveRecord::Migration[7.1]
  def change
    add_column :fee_details, :external_fee_id, :string
    add_index :fee_details, :external_fee_id, unique: true
  end
end
