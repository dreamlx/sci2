ActiveAdmin.register CommunicationWorkOrder do
  # 简化参数 - 只允许沟通相关字段
  permit_params :reimbursement_id, :audit_comment, :communication_method

  menu priority: 5, label: "沟通工单", parent: "工单管理"
  config.sort_order = 'created_at_desc'
  config.remove_action_item :new # 从报销单页面创建
  config.batch_actions = false # 禁用批量操作

  controller do
    before_action :set_current_admin_user_for_model

    def set_current_admin_user_for_model
      Current.admin_user = current_admin_user
    end

    def scoped_collection
      CommunicationWorkOrder.includes(:reimbursement, :creator)
    end

    # 创建时设置报销单ID和创建人
    def build_new_resource
      resource = super
      if params[:reimbursement_id] && resource.reimbursement_id.nil?
        resource.reimbursement_id = params[:reimbursement_id]
      end
      resource.created_by = current_admin_user.id if current_admin_user
      resource
    end
    
    def create
      # 简化参数处理
      communication_work_order_params = params.require(:communication_work_order).permit(
        :reimbursement_id, :audit_comment, :communication_method
      )
      
      @communication_work_order = CommunicationWorkOrder.new(communication_work_order_params)
      @communication_work_order.created_by = current_admin_user.id if current_admin_user
      
      if @communication_work_order.save
        redirect_to admin_communication_work_order_path(@communication_work_order), 
                    notice: '沟通工单创建成功，已自动完成。'
      else
        render :new
      end
    end

    def update
      # 沟通工单创建后不允许编辑
      redirect_to admin_communication_work_order_path(resource), 
                  alert: '沟通工单创建后不允许修改。如需记录新的沟通，请创建新工单。'
    end
  end

  # 简化列表页面
  index do
    id_column
    column "报销单号", :reimbursement do |wo| 
      link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) if wo.reimbursement
    end
    column "沟通方式", :communication_method do |wo|
      status_tag wo.communication_method, class: 'blue' if wo.communication_method
    end
    column "沟通内容", :audit_comment do |wo|
      truncate(wo.audit_comment, length: 50) if wo.audit_comment
    end
    column "创建人", :creator do |wo|
      wo.creator&.name || wo.creator&.email
    end
    column "创建时间", :created_at
    column "状态", :status do |wo|
      status_tag wo.status, class: wo.status == 'completed' ? 'green' : 'orange'
    end
    column "操作" do |work_order|
      link_to("查看", admin_communication_work_order_path(work_order), class: "member_link view_link")
    end
    
    div class: "action_items" do
      span class: "action_item" do
        # 安全地处理 params[:q]，避免传递 nil 或空值
        query_params = params[:q].present? ? { q: params[:q] } : {}
        link_to "导出CSV", export_csv_admin_communication_work_orders_path(query_params), class: "button"
      end
    end
  end

  # 使用默认表单，避免资源为空的问题
  form do |f|
    if f.object.reimbursement || params[:reimbursement_id]
      reimbursement = f.object.reimbursement || Reimbursement.find_by(id: params[:reimbursement_id])
      
      if reimbursement
        f.inputs '基本信息' do
          f.input :reimbursement_id, as: :hidden, input_html: { value: reimbursement.id }
          f.semantic_fields_for :reimbursement, reimbursement do |rf|
            rf.input :invoice_number, label: '报销单号', input_html: { readonly: true, disabled: true }
            rf.input :applicant, label: '申请人', input_html: { readonly: true, disabled: true }
            rf.input :department, label: '部门', input_html: { readonly: true, disabled: true }
            rf.input :amount, label: '金额', input_html: { readonly: true, disabled: true }
          end
        end
        
        f.inputs '沟通记录' do
          f.input :communication_method, label: "沟通方式",
                  as: :select,
                  collection: [['电话', '电话'], ['微信', '微信'], ['邮件', '邮件']],
                  prompt: '请选择沟通方式',
                  input_html: { required: true }
          
          f.input :audit_comment, label: "沟通内容",
                  as: :text,
                  input_html: {
                    rows: 6,
                    placeholder: "请详细记录本次沟通的具体内容...",
                    required: true,
                    minlength: 10
                  }
        end
        
        f.actions
      else
        f.inputs do
          f.li "错误：无法找到关联的报销单"
        end
      end
    else
      f.inputs do
        f.li "错误：沟通工单必须关联到特定的报销单"
      end
    end
  end

  # CSV导出
  collection_action :export_csv, method: :get do
    work_orders = CommunicationWorkOrder.includes(:reimbursement, :creator)
    work_orders = work_orders.ransack(params[:q]).result if params[:q]
    
    csv_data = CSV.generate(headers: true, force_quotes: true) do |csv|
      csv << ['工单ID', '报销单号', '沟通方式', '沟通内容', '创建人', '创建时间', '状态']
      
      work_orders.find_each do |wo|
        csv << [
          wo.id,
          wo.reimbursement&.invoice_number,
          wo.communication_method,
          wo.audit_comment,
          wo.creator&.name || wo.creator&.email,
          wo.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
          wo.status
        ]
      end
    end
    
    send_data csv_data, filename: "沟通工单_#{Date.current.strftime('%Y%m%d')}.csv"
  end

  # 简化显示页面
  show title: proc{|wo| "沟通工单 ##{wo.id}" } do
    div class: "notice" do
      "沟通工单专用于记录电话沟通过程，不会影响费用明细和报销单的验证状态。"
    end
    
    attributes_table do
      row :id
      row "报销单" do |wo|
        if wo.reimbursement
          link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement)
        end
      end
      row "沟通方式", :communication_method
      row "沟通内容", :audit_comment do |wo|
        simple_format(wo.audit_comment) if wo.audit_comment
      end
      row "创建人", :creator do |wo|
        wo.creator&.name || wo.creator&.email
      end
      row "创建时间", :created_at
      row "状态", :status do |wo|
        status_tag wo.status, class: wo.status == 'completed' ? 'green' : 'orange'
      end
    end

    # 显示关联的报销单信息
    if communication_work_order.reimbursement
      panel "关联报销单信息" do
        reimbursement = communication_work_order.reimbursement
        attributes_table_for reimbursement do
          row "报销单号", :invoice_number
          row "申请人", :applicant_name
          row "部门", :department
          row "总金额" do |r|
            number_to_currency(r.amount, unit: "¥")
          end
          row "状态", :status do |r|
            status_tag r.status
          end
        end
      end
    end
  end

  # 暂时完全禁用过滤器 - 任何过滤器都会导致 ArgumentError
  # 这是一个深层的 ActiveAdmin + CanCan + STI 兼容性问题
  config.filters = false
  
  # 所有过滤器都暂时禁用，直到找到根本解决方案
  # filter :id
  # filter :communication_method, as: :select, collection: ['电话', '微信', '邮件', '现场沟通']
  # filter :audit_comment, as: :string, label: "沟通内容"
  # filter :reimbursement_invoice_number, as: :string, label: "报销单号"
  # filter :creator, as: :select, collection: -> { ... }
  # filter :created_at, label: "创建时间"
  # filter :status, as: :select, collection: [['已完成', 'completed'], ['处理中', 'pending']]
  # filter :creator, as: :select, collection: -> {
  #   begin
  #     # 使用更安全的权限检查方式
  #     if defined?(current_ability) && current_ability
  #       begin
  #         accessible_users = AdminUser.accessible_by(current_ability)
  #         collection = accessible_users.map { |u|
  #           label = u.name.presence || u.email.presence || "用户 ##{u.id}"
  #           [label, u.id]
  #         }
  #       rescue CanCan::AccessDenied, NoMethodError => e
  #         Rails.logger.warn "权限检查失败，使用所有用户: #{e.message}"
  #         collection = AdminUser.all.map { |u|
  #           label = u.name.presence || u.email.presence || "用户 ##{u.id}"
  #           [label, u.id]
  #         }
  #       end
  #     else
  #       # 如果没有权限系统，使用所有用户
  #       collection = AdminUser.all.map { |u|
  #         label = u.name.presence || u.email.presence || "用户 ##{u.id}"
  #         [label, u.id]
  #       }
  #     end
  #
  #     # 确保过滤器永远不返回空数组或nil，ActiveAdmin要求至少有一个选项
  #     collection.empty? ? [['无可用用户', '']] : collection
  #   rescue => e
  #     Rails.logger.error "沟通工单页面创建者过滤器系统错误: #{e.message}"
  #     [['系统错误', '']]
  #   end
  # }
  # filter :created_at, label: "创建时间"
  # filter :status, as: :select, collection: [['已完成', 'completed'], ['处理中', 'pending']]
end