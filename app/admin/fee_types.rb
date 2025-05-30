ActiveAdmin.register FeeType do
  menu priority: 2, parent: '数据管理', label: '费用类型库'

  # 允许的参数
  permit_params :code, :title, :meeting_type, :active

  # 控制器自定义
  controller do
    def scoped_collection
      super.includes(:problem_types) # 预加载关联的问题类型
    end
  end

  # 过滤器
  filter :code
  filter :title
  filter :meeting_type, as: :select, collection: -> { ['个人', '学术论坛'] }
  filter :active

  # 列表页
  index do
    selectable_column
    id_column
    column :code
    column :title
    column :meeting_type
    column :active
    column :problem_types do |ft|
      link_to "#{ft.problem_types.count} 个问题类型", admin_problem_types_path(q: { fee_type_id_eq: ft.id })
    end
    column :created_at
    column :updated_at
    actions
  end

  # 详情页
  show do
    attributes_table do
      row :id
      row :code
      row :title
      row :display_name
      row :meeting_type
      row :active
      row :created_at
      row :updated_at
    end

    panel "关联的问题类型" do
      table_for fee_type.problem_types.order(:code) do
        column :id do |pt|
          link_to pt.id, admin_problem_type_path(pt)
        end
        column :code
        column :title
        column :active
      end
    end
  end

  # 表单
  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :code
      f.input :title
      f.input :meeting_type, as: :select, collection: ['个人', '学术论坛']
      f.input :active
    end
    f.actions
  end
  
  # 批量操作
  batch_action :activate do |ids|
    batch_action_collection.find(ids).each do |fee_type|
      fee_type.update(active: true)
    end
    redirect_to collection_path, notice: "已将选中的费用类型设置为激活状态"
  end
  
  batch_action :deactivate do |ids|
    batch_action_collection.find(ids).each do |fee_type|
      fee_type.update(active: false)
    end
    redirect_to collection_path, notice: "已将选中的费用类型设置为非激活状态"
  end
  
  # 自定义操作
  action_item :import_problem_codes, only: :index do
    link_to '导入问题代码', new_admin_import_path(resource: 'problem_codes')
  end
end