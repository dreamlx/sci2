class RemoveVerificationStatusFromFeeDetailSelections < ActiveRecord::Migration[7.0]
  def change
    remove_column :fee_detail_selections, :verification_status, :string
  end
end
