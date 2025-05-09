class AddProblemTypeAndDescriptionToWorkOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :work_orders, :problem_type_id, :integer
    add_column :work_orders, :problem_description_id, :integer
    add_column :work_orders, :material_ids, :text
  end
end
