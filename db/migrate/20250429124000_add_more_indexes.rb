class AddMoreIndexes < ActiveRecord::Migration[7.1]
  def change
    # For reimbursements table - only adding indexes that don't exist yet
    add_index :reimbursements, :external_status
    add_index :reimbursements, :is_electronic

    # For fee_details table - only adding indexes that don't exist yet
    add_index :fee_details, :fee_date

    # For operation_histories table - only adding indexes that don't exist yet
    add_index :operation_histories, :operation_time
  end
end
