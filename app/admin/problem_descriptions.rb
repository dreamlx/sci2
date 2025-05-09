ActiveAdmin.register ProblemDescription do
  menu parent: '数据管理'

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :problem_type_id, :description
  #
  # or
  #
  # permit_params do
  #   permitted = [:problem_type_id, :description]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end
  
  index do
    selectable_column
    id_column
    column :problem_type
    column :description
    actions
  end

  filter :problem_type
  filter :description

  show do
    attributes_table do
      row :id
      row :problem_type
      row :description
    end
    active_admin_comments
  end
end
