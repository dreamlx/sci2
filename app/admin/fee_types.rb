ActiveAdmin.register FeeType do
  permit_params :code, :title, :meeting_type, :active

  menu priority: 6, label: "会议/费用类型", parent: "系统设置"

  # 过滤器
  filter :code
  filter :title
  filter :meeting_type
  filter :active

  # 批量操作
  batch_action :activate do |ids|
    batch_action_collection.find(ids).each do |fee_type|
      fee_type.update(active: true)
    end
    redirect_to collection_path, notice: "已激活选中的费用类型"
  end

  batch_action :deactivate do |ids|
    batch_action_collection.find(ids).each do |fee_type|
      fee_type.update(active: false)
    end
    redirect_to collection_path, notice: "已停用选中的费用类型"
  end

  # 范围过滤器
  scope :all, default: true
  scope :active
  scope :by_meeting_type, ->(type) { where(meeting_type: type) }, if: proc { params[:meeting_type].present? }

  # 列表页
  index do
    selectable_column
    id_column
    column :code
    column :title
    column :meeting_type
    column :active
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
      row :meeting_type
      row :active
      row :created_at
      row :updated_at
    end

    panel "关联的问题类型" do
      table_for fee_type.problem_types do
        column :id
        column :code
        column :title
        column :active
        column :created_at
        column :updated_at
        column "操作" do |problem_type|
          links = []
          links << link_to("查看", admin_problem_type_path(problem_type))
          links << link_to("编辑", edit_admin_problem_type_path(problem_type))
          links.join(" | ").html_safe
        end
      end
    end
  end

  # 表单
  form do |f|
    f.inputs do
      f.input :code
      f.input :title
      f.input :meeting_type, as: :select, collection: ["个人", "学术论坛"]
      f.input :active
    end
    f.actions
  end

  # 添加JSON端点
  # 移除重复的collection_action，使用controller中的index方法统一处理
  
  controller do
    before_action :authenticate_admin_user!, except: [:index]
    
    def index
      respond_to do |format|
        format.html { super }
        format.json {
          @fee_types = if params[:meeting_type].present?
                       FeeType.active.by_meeting_type(params[:meeting_type])
                     else
                       FeeType.active
                     end
          render json: @fee_types.as_json(
            only: [:id, :code, :title, :meeting_type],
            methods: [:display_name]
          )
        }
      end
    end
  end
end