ActiveAdmin.register ReimbursementAssignment do
  menu label: "报销单分配", priority: 5
  
  # 权限控制
  actions :index, :show, :new, :create, :update
  
  # 过滤器
  filter :reimbursement_invoice_number, as: :string, label: "发票号"
  filter :assignee, label: "被分配人"
  filter :assigner, label: "分配人"
  filter :is_active, as: :boolean, label: "是否活跃"
  filter :created_at, label: "分配时间"
  
  # 列表页
  index do
    selectable_column
    id_column
    column :reimbursement do |assignment|
      link_to assignment.reimbursement.invoice_number, admin_reimbursement_path(assignment.reimbursement)
    end
    column :assignee
    column :assigner
    column :is_active do |assignment|
      status_tag assignment.is_active? ? "活跃" : "已取消", class: assignment.is_active? ? "green" : "red"
    end
    column :created_at
    actions
  end
  
  # 详情页
  show do
    attributes_table do
      row :id
      row :reimbursement do |assignment|
        link_to assignment.reimbursement.invoice_number, admin_reimbursement_path(assignment.reimbursement)
      end
      row :assignee
      row :assigner
      row :is_active do |assignment|
        status_tag assignment.is_active? ? "活跃" : "已取消", class: assignment.is_active? ? "green" : "red"
      end
      row :notes
      row :created_at
      row :updated_at
    end
  end
  
  # 表单
  form do |f|
    f.inputs "报销单分配" do
      f.input :reimbursement, collection: Reimbursement.all.map { |r| [r.invoice_number, r.id] }
      f.input :assignee, collection: AdminUser.all
      f.input :is_active
      f.input :notes
    end
    f.actions
  end
  
  # 批量操作
  batch_action :assign_to, form: -> {
    {
      assignee: AdminUser.all.map { |u| [u.email, u.id] },
      notes: :text
    }
  } do |ids, inputs|
    service = ReimbursementAssignmentService.new(current_admin_user)
    reimbursement_ids = ReimbursementAssignment.where(id: ids).pluck(:reimbursement_id)
    
    results = service.batch_assign(reimbursement_ids, inputs[:assignee], inputs[:notes])
    
    redirect_to collection_path, notice: "成功分配 #{results.size} 个报销单"
  end
  
  # 控制器自定义
  controller do
    def create
      service = ReimbursementAssignmentService.new(current_admin_user)
      @reimbursement_assignment = service.assign(
        params[:reimbursement_assignment][:reimbursement_id],
        params[:reimbursement_assignment][:assignee_id],
        params[:reimbursement_assignment][:notes]
      )
      
      if @reimbursement_assignment.persisted?
        redirect_to admin_reimbursement_assignment_path(@reimbursement_assignment), notice: "报销单分配成功"
      else
        render :new
      end
    end
    
    def update
      @reimbursement_assignment = ReimbursementAssignment.find(params[:id])
      
      if @reimbursement_assignment.update(permitted_params[:reimbursement_assignment])
        redirect_to admin_reimbursement_assignment_path(@reimbursement_assignment), notice: "报销单分配更新成功"
      else
        render :edit
      end
    end
    
    def scoped_collection
      super.includes(:reimbursement, :assignee, :assigner)
    end
  end
  
  # 允许的参数
  permit_params :reimbursement_id, :assignee_id, :is_active, :notes
end