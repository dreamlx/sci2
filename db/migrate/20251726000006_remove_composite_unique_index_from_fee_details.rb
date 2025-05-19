class RemoveCompositeUniqueIndexFromFeeDetails < ActiveRecord::Migration[7.1]
  def change
    remove_index :fee_details, name: "index_fee_details_on_document_and_details", if_exists: true
    # 如果你还想保留这个索引但只是取消唯一性，可以先remove再add:
    # remove_index :fee_details, name: "index_fee_details_on_document_and_details", if_exists: true
    # add_index :fee_details, ["document_number", "fee_type", "amount", "fee_date"], name: "index_fee_details_on_document_and_details" 
    # 但通常如果 external_fee_id 是权威唯一键，这个旧索引的唯一性就不再必要
  end
end
