ActiveAdmin.register ProblemType do
  menu priority: 3, parent: '数据管理', label: '问题代码库'

  # 允许的参数
  permit_params :code, :title, :sop_description, :standard_handling, :fee_type_id, :active

  # 控制器自定义
  controller do
    def scoped_collection
      super.includes(:fee_type) # 预加载关联的费用类型
    end
    
    # 添加JSON格式支持，用于级联下拉选择
    def index
      super do |format|
        format.json do
          @problem_types = ProblemType.active
          @problem_types = @problem_types.by_fee_type(params[:fee_type_id]) if params[:fee_type_id].present?
          
          render json: @problem_types.map { |pt|
            {
              id: pt.id,
              code: pt.code,
              title: pt.title,
              display_name: pt.display_name,
              fee_type_id: pt.fee_type_id,
              fee_type_name: pt.fee_type&.display_name || "未关联费用类型",
              sop_description: pt.sop_description,
              standard_handling: pt.standard_handling
            }
          }
        end
      end
    end
  end

  # 过滤器
  filter :fee_type, collection: proc { FeeType.active.order(:code) }
  filter :code
  filter :title
  filter :active

  # 列表页
  index do
    selectable_column
    id_column
    column :fee_type do |pt|
      if pt.fee_type.present?
        link_to pt.fee_type.display_name, admin_fee_type_path(pt.fee_type)
      else
        "未关联费用类型"
      end
    end
    column :code
    column :title
    column :active
    column :created_at
    column :updated_at
    actions
  end

  # 详情页
  show do
    attributes_table do
      row :id
      row :fee_type do |pt|
        if pt.fee_type.present?
          link_to pt.fee_type.display_name, admin_fee_type_path(pt.fee_type)
        else
          "未关联费用类型"
        end
      end
      row :code
      row :title
      row :display_name
      row :sop_description
      row :standard_handling
      row :active
      row :created_at
      row :updated_at
    end
  end

  # 表单
  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :fee_type, collection: FeeType.active.order(:code).map { |ft| [ft.display_name, ft.id] }
      f.input :code
      f.input :title
      f.input :sop_description
      f.input :standard_handling
      f.input :active
    end
    f.actions
  end
  
  # 批量操作
  batch_action :activate do |ids|
    batch_action_collection.find(ids).each do |problem_type|
      problem_type.update(active: true)
    end
    redirect_to collection_path, notice: "已将选中的问题类型设置为激活状态"
  end
  
  batch_action :deactivate do |ids|
    batch_action_collection.find(ids).each do |problem_type|
      problem_type.update(active: false)
    end
    redirect_to collection_path, notice: "已将选中的问题类型设置为非激活状态"
  end
end
