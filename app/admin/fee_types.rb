ActiveAdmin.register FeeType do
  permit_params :reimbursement_type_code, :meeting_type_code, :expense_type_code, :name, :meeting_name, :active

  menu priority: 6, label: '费用类型', parent: '系统设置'

  # 过滤器
  filter :reimbursement_type_code
  filter :meeting_type_code
  filter :expense_type_code
  filter :name
  filter :meeting_name
  filter :active

  # 批量操作
  batch_action :activate do |ids|
    batch_action_collection.find(ids).each do |fee_type|
      fee_type.update(active: true)
    end
    redirect_to collection_path, notice: '已激活选中的费用类型'
  end

  batch_action :deactivate do |ids|
    batch_action_collection.find(ids).each do |fee_type|
      fee_type.update(active: false)
    end
    redirect_to collection_path, notice: '已停用选中的费用类型'
  end

  # 范围过滤器
  scope :all, default: true
  scope :active

  # 列表页
  index do
    selectable_column
    id_column
    column '报销类型', :reimbursement_type_code
    column '会议代码', :meeting_type_code
    column '会议名称', :meeting_name
    column '费用代码', :expense_type_code
    column '费用类型名称', :name
    column '是否启用', :active
    column '创建时间', :created_at
    actions
  end

  # 详情页
  show do
    attributes_table do
      row :id
      row :name
      row :reimbursement_type_code
      row :meeting_name
      row :meeting_type_code
      row :expense_type_code
      row :active
      row :created_at
      row :updated_at
    end

    panel '关联的问题类型' do
      table_for fee_type.problem_types do
        column :id
        column :issue_code
        column :title
        column :active
        column '操作' do |problem_type|
          link_to('查看', admin_problem_type_path(problem_type))
        end
      end
    end
  end

  # 表单
  form do |f|
    f.inputs do
      f.input :name
      f.input :reimbursement_type_code
      f.input :meeting_name
      f.input :meeting_type_code
      f.input :expense_type_code
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
        # 添加CSV格式支持
        format.csv { super }
        format.json do
          @fee_types = FeeType.active
          # Add filtering based on params if needed in the future
          render json: @fee_types.as_json(
            only: %i[id name reimbursement_type_code meeting_type_code expense_type_code],
            methods: [:display_name]
          )
        end
      end
    end

    def create
      authorize! :manage, FeeType
      super
    end

    def update
      authorize! :manage, resource
      super
    end

    def destroy
      authorize! :manage, resource
      super
    end
  end
end
