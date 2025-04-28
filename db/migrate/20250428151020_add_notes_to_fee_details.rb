class AddNotesToFeeDetails < ActiveRecord::Migration[7.1]
  def change
    add_column :fee_details, :notes, :text
  end
end
