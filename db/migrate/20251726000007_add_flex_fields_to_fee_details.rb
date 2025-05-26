class AddFlexFieldsToFeeDetails < ActiveRecord::Migration[7.1]
  def change
    add_column :fee_details, :flex_field_6, :string
    add_column :fee_details, :flex_field_7, :string
  end
end
