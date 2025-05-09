ActiveAdmin.register ProblemTypeMaterial do
  menu parent: '数据管理'

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :problem_type_id, :material_id
  #
  # or
  #
  # permit_params do
  #   permitted = [:problem_type_id, :material_id]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end
  
  index do
    selectable_column
    id_column
    column :problem_type
    column :material
    actions
  end

  filter :problem_type
  filter :material

  show do
    attributes_table do
      row :id
      row :problem_type
      row :material
    end
    active_admin_comments
  end
end
