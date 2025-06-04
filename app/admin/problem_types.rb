ActiveAdmin.register ProblemType do
  permit_params :code, :title, :sop_description, :standard_handling, :fee_type_id, :active

  menu priority: 7, label: "问题类型", parent: "系统设置"

  # 过滤器
  filter :code
  filter :title
  filter :fee_type
  filter :active

  # 批量操作
  batch_action :activate do |ids|
    batch_action_collection.find(ids).each do |problem_type|
      problem_type.update(active: true)
    end
    redirect_to collection_path, notice: "已激活选中的问题类型"
  end

  batch_action :deactivate do |ids|
    batch_action_collection.find(ids).each do |problem_type|
      problem_type.update(active: false)
    end
    redirect_to collection_path, notice: "已停用选中的问题类型"
  end

  # 范围过滤器
  scope :all, default: true
  scope :active
  scope :by_fee_type, ->(fee_type_id) { where(fee_type_id: fee_type_id) }, if: proc { params[:fee_type_id].present? }

  # 列表页
  index do
    selectable_column
    id_column
    column :code
    column :title
    column :fee_type
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
      row :fee_type
      row :sop_description
      row :standard_handling
      row :active
      row :created_at
      row :updated_at
    end
  end

  # 表单
  form do |f|
    f.inputs do
      f.input :fee_type
      f.input :code
      f.input :title
      f.input :sop_description
      f.input :standard_handling
      f.input :active
    end
    f.actions
  end

  # 添加JSON端点
  collection_action :index, format: :json do
    if params[:fee_type_id].present?
      # 单个费用类型查询
      @problem_types = ProblemType.active.by_fee_type(params[:fee_type_id])
    elsif params[:fee_type_ids].present?
      # 多个费用类型查询
      fee_type_ids = params[:fee_type_ids].split(',')
      @problem_types = ProblemType.active.where(fee_type_id: fee_type_ids)
    else
      @problem_types = ProblemType.active
    end
    
    render json: @problem_types.as_json(
      only: [:id, :code, :title, :fee_type_id, :sop_description, :standard_handling],
      methods: [:display_name]
    )
  end

  # 确保HTML格式的index正常工作
  controller do
    def index
      super do |format|
        format.html { render :index }
        format.json { render json: @problem_types }
      end
    end
  end
end
