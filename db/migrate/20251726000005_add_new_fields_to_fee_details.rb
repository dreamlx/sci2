class AddNewFieldsToFeeDetails < ActiveRecord::Migration[7.1]
  def change
    add_column :fee_details, :plan_or_pre_application, :string # 计划/预申请
    add_column :fee_details, :product, :string                   # 产品
    add_column :fee_details, :flex_field_11, :string             # 弹性字段11
    add_column :fee_details, :expense_corresponding_plan, :string # 费用对应计划
    add_column :fee_details, :expense_associated_application, :string # 费用关联申请单
  end
end
