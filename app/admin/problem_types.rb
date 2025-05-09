ActiveAdmin.register ProblemType do
  menu parent: '数据管理'

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  permit_params :name
  #
  # or
  #
  # permit_params do
  #   permitted = [:name]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end
  
  index do
    selectable_column
    id_column
    column :name
    column "关联费用类型" do |pt|
      pt.fee_types.map(&:name).join(', ')
    end
    column "关联补充材料" do |pt|
      pt.materials.map(&:name).join(', ')
    end
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row "关联费用类型" do |pt|
        pt.fee_types.map(&:name).join(', ')
      end
      row "关联补充材料" do |pt|
        pt.materials.map(&:name).join(', ')
      end
    end
    active_admin_comments
  end
end
