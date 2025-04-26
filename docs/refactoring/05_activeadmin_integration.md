# SCI2 工单系统ActiveAdmin集成

## 1. ActiveAdmin概述

ActiveAdmin是一个Ruby on Rails插件，用于生成管理界面。在SCI2工单系统中，我们将使用ActiveAdmin来实现管理界面，包括工单列表、详情页、表单等。

### 1.1 ActiveAdmin配置

```ruby
# config/initializers/active_admin.rb
ActiveAdmin.setup do |config|
  # 设置站点标题
  config.site_title = "SCI2工单系统"
  
  # 设置默认命名空间
  config.default_namespace = :admin
  
  # 设置根路径
  config.root_to = 'dashboard#index'
  
  # 启用批量操作
  config.batch_actions = true
  
  # 设置每页显示记录数
  config.default_per_page = 30
  
  # 设置CSV下载选项
  config.csv_options = { col_sep: ',', force_quotes: true }
  
  # 设置过滤器位置
  config.filters_position = :right
  
  # 设置注释
  config.comments = false
end
```

## 2. 资源注册

### 2.1 报销单资源

```ruby
# app/admin/reimbursements.rb
ActiveAdmin.register Reimbursement do
  # 权限控制
  permit_params :invoice_number, :document_name, :applicant, :applicant_id, :company, :department, 
                :amount, :receipt_status, :reimbursement_status, :receipt_date, :submission_date, 
                :is_electronic, :is_complete
  
  # 菜单设置
  menu priority: 1, label: "报销单管理"
  
  # 过滤器
  filter :invoice_number
  filter :applicant
  filter :company
  filter :department
  filter :receipt_status, as: :select, collection: ["pending", "received"]
  filter :reimbursement_status, as: :select, collection: ["pending", "processing", "closed"]
  filter :is_electronic, as: :boolean
  filter :is_complete, as: :boolean
  filter :created_at
  
  # 批量操作
  batch_action :mark_as_received do |ids|
    batch_action_collection.find(ids).each do |reimbursement|
      reimbursement.mark_as_received
    end
    redirect_to collection_path, notice: "已将选中的报销单标记为已收单"
  end
  
  # 自定义操作
  action_item :import, only: :index do
    link_to "导入报销单", new_import_admin_reimbursements_path
  end
  
  # 自定义页面
  collection_action :new_import, method: :get do
    render "admin/reimbursements/new_import"
  end
  
  collection_action :import, method: :post do
    redirect_to admin_reimbursements_path, notice: "导入成功"
  end
  
  # 列表页
  index do
    selectable_column
    id_column
    column :invoice_number
    column :applicant
    column :amount do |reimbursement|
      number_to_currency(reimbursement.amount, unit: "¥")
    end
    column :receipt_status do |reimbursement|
      status_tag reimbursement.receipt_status
    end
    column :reimbursement_status do |reimbursement|
      status_tag reimbursement.reimbursement_status
    end
    column :is_electronic
    column :is_complete
    column :created_at
    actions
  end
  
  # 详情页
  show do
    tabs do
      tab "基本信息" do
        attributes_table do
          row :invoice_number
          row :document_name
          row :applicant
          row :applicant_id
          row :company
          row :department
          row :amount do |reimbursement|
            number_to_currency(reimbursement.amount, unit: "¥")
          end
          row :receipt_status
          row :reimbursement_status
          row :receipt_date
          row :submission_date
          row :is_electronic
          row :is_complete
          row :created_at
          row :updated_at
        end
      end
      
      tab "快递收单" do
        panel "快递收单信息" do
          table_for resource.express_receipt_work_orders do
            column :id
            column :tracking_number
            column :received_at
            column :courier_name
            column :status
            column :created_at
            column "操作" do |work_order|
              links = []
              links << link_to("查看", admin_express_receipt_work_order_path(work_order))
              links.join(" | ").html_safe
            end
          end
        end
      end
      
      tab "审核工单" do
        panel "审核工单信息" do
          table_for resource.audit_work_orders do
            column :id
            column :status
            column :audit_result
            column :audit_date
            column :created_at
            column "操作" do |work_order|
              links = []
              links << link_to("查看", admin_audit_work_order_path(work_order))
              links.join(" | ").html_safe
            end
          end
        end
      end
      
      tab "沟通工单" do
        panel "沟通工单信息" do
          table_for resource.communication_work_orders do
            column :id
            column :status
            column :communication_method
            column :initiator_role
            column :created_at
            column "操作" do |work_order|
              links = []
              links << link_to("查看", admin_communication_work_order_path(work_order))
              links.join(" | ").html_safe
            end
          end
        end
      end
      
      tab "费用明细" do
        panel "费用明细信息" do
          table_for resource.fee_details do
            column :id
            column :fee_type
            column :amount do |fee_detail|
              number_to_currency(fee_detail.amount, unit: "¥")
            end
            column :fee_date
            column :verification_status
            column :created_at
            column "操作" do |fee_detail|
              links = []
              links << link_to("查看", admin_fee_detail_path(fee_detail))
              links.join(" | ").html_safe
            end
# 表单
  form do |f|
    f.inputs "报销单信息" do
      f.input :invoice_number
      f.input :document_name
      f.input :applicant
      f.input :applicant_id
      f.input :company
      f.input :department
      f.input :amount
      f.input :receipt_status, as: :select, collection: ["pending", "received"]
      f.input :reimbursement_status, as: :select, collection: ["pending", "processing", "closed"]
      f.input :receipt_date, as: :datepicker
      f.input :submission_date, as: :datepicker
      f.input :is_electronic
      f.input :is_complete
    end
    f.actions
  end
end
```

### 2.2 快递收单工单资源

```ruby
# app/admin/express_receipt_work_orders.rb
ActiveAdmin.register ExpressReceiptWorkOrder do
  # 权限控制
  permit_params :reimbursement_id, :status, :tracking_number, :received_at, :courier_name, :created_by
  
  # 菜单设置
  menu priority: 2, label: "快递收单工单"
  
  # 过滤器
  filter :reimbursement_id
  filter :tracking_number
  filter :status, as: :select, collection: ["received", "processed", "completed"]
  filter :received_at
  filter :created_at
  
  # 批量操作
  batch_action :process do |ids|
    batch_action_collection.find(ids).each do |work_order|
      ExpressReceiptWorkOrderService.new(work_order, current_admin_user).process
    end
    redirect_to collection_path, notice: "已将选中的工单标记为已处理"
  end
  
  batch_action :complete do |ids|
    batch_action_collection.find(ids).each do |work_order|
      ExpressReceiptWorkOrderService.new(work_order, current_admin_user).complete
    end
    redirect_to collection_path, notice: "已将选中的工单标记为已完成"
  end
  
  # 自定义操作
  action_item :process, only: :show, if: proc { resource.status == "received" } do
    link_to "处理", process_admin_express_receipt_work_order_path(resource), method: :put
  end
  
  action_item :complete, only: :show, if: proc { resource.status == "processed" } do
    link_to "完成", complete_admin_express_receipt_work_order_path(resource), method: :put
  end
  
  # 自定义页面
  member_action :process, method: :put do
    service = ExpressReceiptWorkOrderService.new(resource, current_admin_user)
    if service.process
      redirect_to admin_express_receipt_work_order_path(resource), notice: "工单已处理"
    else
      redirect_to admin_express_receipt_work_order_path(resource), alert: "操作失败"
    end
  end
  
  member_action :complete, method: :put do
    service = ExpressReceiptWorkOrderService.new(resource, current_admin_user)
    if service.complete
      redirect_to admin_express_receipt_work_order_path(resource), notice: "工单已完成"
    else
      redirect_to admin_express_receipt_work_order_path(resource), alert: "操作失败"
    end
  end
  
  # 列表页
  index do
    selectable_column
    id_column
    column :reimbursement do |work_order|
      link_to work_order.reimbursement.invoice_number, admin_reimbursement_path(work_order.reimbursement)
    end
    column :tracking_number
    column :status do |work_order|
      status_tag work_order.status
    end
    column :received_at
    column :courier_name
    column :created_at
    actions
  end
  
  # 详情页
  show do
    attributes_table do
      row :id
      row :reimbursement do |work_order|
        link_to work_order.reimbursement.invoice_number, admin_reimbursement_path(work_order.reimbursement)
      end
      row :tracking_number
      row :status do |work_order|
        status_tag work_order.status
      end
      row :received_at
      row :courier_name
      row :created_by
      row :created_at
      row :updated_at
    end
    
    panel "状态变更历史" do
      table_for resource.work_order_status_changes.order(changed_at: :desc) do
        column :from_status
        column :to_status
        column :changed_at
        column :changed_by
      end
    end
    
    panel "关联的审核工单" do
      if resource.audit_work_order.present?
        attributes_table_for resource.audit_work_order do
          row :id do |work_order|
            link_to work_order.id, admin_audit_work_order_path(work_order)
          end
          row :status do |work_order|
            status_tag work_order.status
          end
          row :created_at
        end
      else
        para "暂无关联的审核工单"
      end
    end
  end
  
  # 表单
  form do |f|
    f.inputs "快递收单工单信息" do
      f.input :reimbursement_id, as: :select, collection: Reimbursement.all.map { |r| [r.invoice_number, r.id] }
      f.input :status, as: :select, collection: ["received", "processed", "completed"]
      f.input :tracking_number
      f.input :received_at, as: :datepicker
      f.input :courier_name
      f.input :created_by, input_html: { value: current_admin_user.id }, as: :hidden
    end
    f.actions
  end
end
```

### 2.3 审核工单资源

```ruby
# app/admin/audit_work_orders.rb
ActiveAdmin.register AuditWorkOrder do
  # 权限控制
  permit_params :reimbursement_id, :express_receipt_work_order_id, :status, :audit_result, 
                :audit_comment, :audit_date, :vat_verified, :created_by
  
  # 菜单设置
  menu priority: 3, label: "审核工单"
  
  # 过滤器
  filter :reimbursement_id
  filter :status, as: :select, collection: ["pending", "processing", "auditing", "approved", "rejected", "needs_communication", "completed"]
  filter :audit_result, as: :select, collection: ["approved", "rejected"]
  filter :audit_date
  filter :created_at
  
  # 批量操作
  batch_action :start_processing do |ids|
    batch_action_collection.find(ids).each do |work_order|
      AuditWorkOrderService.new(work_order, current_admin_user).start_processing
    end
    redirect_to collection_path, notice: "已将选中的工单标记为处理中"
  end
  
  # 自定义操作
  action_item :start_processing, only: :show, if: proc { resource.status == "pending" } do
    link_to "开始处理", start_processing_admin_audit_work_order_path(resource), method: :put
  end
  
  action_item :start_audit, only: :show, if: proc { resource.status == "processing" } do
    link_to "开始审核", start_audit_admin_audit_work_order_path(resource), method: :put
  end
  
  action_item :approve, only: :show, if: proc { resource.status == "auditing" } do
    link_to "审核通过", approve_admin_audit_work_order_path(resource)
  end
  
  action_item :reject, only: :show, if: proc { resource.status == "auditing" } do
# 自定义页面
  member_action :start_processing, method: :put do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    if service.start_processing
      redirect_to admin_audit_work_order_path(resource), notice: "工单已开始处理"
    else
      redirect_to admin_audit_work_order_path(resource), alert: "操作失败"
    end
  end
  
  member_action :start_audit, method: :put do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    if service.start_audit
      redirect_to admin_audit_work_order_path(resource), notice: "工单已开始审核"
    else
      redirect_to admin_audit_work_order_path(resource), alert: "操作失败"
    end
  end
  
  member_action :approve, method: :get do
    render "admin/audit_work_orders/approve"
  end
  
  member_action :do_approve, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    if service.approve(params[:comment])
      redirect_to admin_audit_work_order_path(resource), notice: "审核已通过"
    else
      redirect_to admin_audit_work_order_path(resource), alert: "操作失败"
    end
  end
  
  member_action :reject, method: :get do
    render "admin/audit_work_orders/reject"
  end
  
  member_action :do_reject, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    if service.reject(params[:comment])
      redirect_to admin_audit_work_order_path(resource), notice: "审核已拒绝"
    else
      redirect_to admin_audit_work_order_path(resource), alert: "操作失败"
    end
  end
  
  member_action :new_communication, method: :get do
    @fee_details = resource.reimbursement.fee_details
    render "admin/audit_work_orders/new_communication"
  end
  
  member_action :create_communication, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    communication_work_order = service.create_communication_work_order(
      communication_method: params[:communication_method],
      initiator_role: params[:initiator_role],
      content: params[:content],
      fee_detail_ids: params[:fee_detail_ids]
    )
    
    if communication_work_order.persisted?
      redirect_to admin_communication_work_order_path(communication_work_order), notice: "沟通工单已创建"
    else
      redirect_to admin_audit_work_order_path(resource), alert: "创建沟通工单失败"
    end
  end
  
  member_action :complete, method: :put do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    if service.complete
      redirect_to admin_audit_work_order_path(resource), notice: "工单已完成"
    else
      redirect_to admin_audit_work_order_path(resource), alert: "操作失败"
    end
  end
  
  # 列表页
  index do
    selectable_column
    id_column
    column :reimbursement do |work_order|
      link_to work_order.reimbursement.invoice_number, admin_reimbursement_path(work_order.reimbursement)
    end
    column :status do |work_order|
      status_tag work_order.status
    end
    column :audit_result do |work_order|
      status_tag work_order.audit_result if work_order.audit_result.present?
    end
    column :audit_date
    column :created_at
    actions
  end
  
  # 详情页
  show do
    tabs do
      tab "基本信息" do
        attributes_table do
          row :id
          row :reimbursement do |work_order|
            link_to work_order.reimbursement.invoice_number, admin_reimbursement_path(work_order.reimbursement)
          end
          row :express_receipt_work_order do |work_order|
            if work_order.express_receipt_work_order.present?
              link_to work_order.express_receipt_work_order.id, admin_express_receipt_work_order_path(work_order.express_receipt_work_order)
            end
          end
          row :status do |work_order|
            status_tag work_order.status
          end
          row :audit_result do |work_order|
            status_tag work_order.audit_result if work_order.audit_result.present?
          end
          row :audit_comment
          row :audit_date
          row :vat_verified
          row :created_by
          row :created_at
          row :updated_at
        end
      end
      
      tab "费用明细" do
        panel "费用明细信息" do
          table_for resource.fee_details do
            column :id
            column :fee_type
            column :amount do |fee_detail|
              number_to_currency(fee_detail.amount, unit: "¥")
            end
            column :verification_status do |fee_detail|
              status_tag fee_detail.verification_status
            end
            column "验证状态" do |fee_detail|
              selection = resource.fee_detail_selections.find_by(fee_detail: fee_detail)
              status_tag selection.verification_status if selection.present?
            end
            column "操作" do |fee_detail|
              links = []
              links << link_to("查看", admin_fee_detail_path(fee_detail))
              links << link_to("验证", verify_admin_fee_detail_path(fee_detail, work_order_id: resource.id))
              links << link_to("标记问题", mark_problematic_admin_fee_detail_path(fee_detail, work_order_id: resource.id))
              links.join(" | ").html_safe
            end
          end
        end
      end
      
      tab "沟通工单" do
        panel "沟通工单信息" do
          table_for resource.communication_work_orders do
            column :id
            column :status do |work_order|
              status_tag work_order.status
            end
            column :communication_method
            column :initiator_role
            column :created_at
            column "操作" do |work_order|
              links = []
              links << link_to("查看", admin_communication_work_order_path(work_order))
              links.join(" | ").html_safe
            end
          end
        end
      end
      
      tab "状态变更历史" do
        panel "状态变更历史" do
          table_for resource.work_order_status_changes.order(changed_at: :desc) do
            column :from_status
            column :to_status
            column :changed_at
            column :changed_by
          end
        end
      end
    end
  end
  
  # 表单
  form do |f|
    f.inputs "审核工单信息" do
      f.input :reimbursement_id, as: :select, collection: Reimbursement.all.map { |r| [r.invoice_number, r.id] }
      f.input :express_receipt_work_order_id, as: :select, collection: ExpressReceiptWorkOrder.all.map { |w| [w.id, w.id] }
      f.input :status, as: :select, collection: ["pending", "processing", "auditing", "approved", "rejected", "needs_communication", "completed"]
      f.input :audit_result, as: :select, collection: ["approved", "rejected"]
      f.input :audit_comment
      f.input :audit_date, as: :datepicker
      f.input :vat_verified
      f.input :created_by, input_html: { value: current_admin_user.id }, as: :hidden
    end
    f.actions
  end
end
```

### 2.4 沟通工单资源

```ruby
# app/admin/communication_work_orders.rb
ActiveAdmin.register CommunicationWorkOrder do
  # 权限控制
  permit_params :reimbursement_id, :audit_work_order_id, :status, :communication_method, 
                :initiator_role, :resolution_summary, :created_by
  
  # 菜单设置
  menu priority: 4, label: "沟通工单"
  
  # 过滤器
  filter :reimbursement_id
  filter :audit_work_order_id
  filter :status, as: :select, collection: ["open", "in_progress", "resolved", "unresolved", "closed"]
  filter :communication_method
  filter :initiator_role
  filter :created_at
  
  # 自定义操作
  action_item :start_communication, only: :show, if: proc { resource.status == "open" } do
    link_to "开始沟通", start_communication_admin_communication_work_order_path(resource), method: :put
  end
  
  action_item :add_communication_record, only: :show, if: proc { resource.status == "in_progress" } do
    link_to "添加沟通记录", new_communication_record_admin_communication_work_order_path(resource)
  end
  
  action_item :resolve, only: :show, if: proc { resource.status == "in_progress" } do
    link_to "标记已解决", resolve_admin_communication_work_order_path(resource)
  end
  
  action_item :mark_unresolved, only: :show, if: proc { resource.status == "in_progress" } do
    link_to "标记未解决", mark_unresolved_admin_communication_work_order_path(resource)
  end
  
  action_item :close, only: :show, if: proc { ["resolved", "unresolved"].include?(resource.status) } do
    link_to "关闭", close_admin_communication_work_order_path(resource), method: :put
  end
    link_to "审核拒绝", reject_admin_audit_work_order_path(resource)
  end
  
  action_item :need_communication, only: :show, if: proc { resource.status == "auditing" } do
    link_to "需要沟通", new_communication_admin_audit_work_order_path(resource)
  end
  
  action_item :complete, only: :show, if: proc { ["approved", "rejected"].include?(resource.status) } do
    link_to "完成", complete_admin_audit_work_order_path(resource), method: :put
  end
          end
        end
      end
    end
  end
# 自定义页面
  member_action :start_communication, method: :put do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    if service.start_communication
      redirect_to admin_communication_work_order_path(resource), notice: "工单已开始沟通"
    else
      redirect_to admin_communication_work_order_path(resource), alert: "操作失败"
    end
  end
  
  member_action :new_communication_record, method: :get do
    render "admin/communication_work_orders/new_communication_record"
  end
  
  member_action :create_communication_record, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    communication_record = service.add_communication_record(
      content: params[:content],
      communicator_role: params[:communicator_role],
      communicator_name: params[:communicator_name],
      communication_method: params[:communication_method]
    )
    
    if communication_record.persisted?
      redirect_to admin_communication_work_order_path(resource), notice: "沟通记录已添加"
    else
      redirect_to admin_communication_work_order_path(resource), alert: "添加沟通记录失败"
    end
  end
  
  member_action :resolve, method: :get do
    render "admin/communication_work_orders/resolve"
  end
  
  member_action :do_resolve, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    if service.resolve(params[:resolution_summary])
      redirect_to admin_communication_work_order_path(resource), notice: "工单已标记为已解决"
    else
      redirect_to admin_communication_work_order_path(resource), alert: "操作失败"
    end
  end
  
  member_action :mark_unresolved, method: :get do
    render "admin/communication_work_orders/mark_unresolved"
  end
  
  member_action :do_mark_unresolved, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    if service.mark_unresolved(params[:resolution_summary])
      redirect_to admin_communication_work_order_path(resource), notice: "工单已标记为未解决"
    else
      redirect_to admin_communication_work_order_path(resource), alert: "操作失败"
    end
  end
  
  member_action :close, method: :put do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    if service.close
      redirect_to admin_communication_work_order_path(resource), notice: "工单已关闭"
    else
      redirect_to admin_communication_work_order_path(resource), alert: "操作失败"
    end
  end
  
  # 列表页
  index do
    selectable_column
    id_column
    column :reimbursement do |work_order|
      link_to work_order.reimbursement.invoice_number, admin_reimbursement_path(work_order.reimbursement)
    end
    column :audit_work_order do |work_order|
      link_to work_order.audit_work_order.id, admin_audit_work_order_path(work_order.audit_work_order)
    end
    column :status do |work_order|
      status_tag work_order.status
    end
    column :communication_method
    column :initiator_role
    column :created_at
    actions
  end
  
  # 详情页
  show do
    tabs do
      tab "基本信息" do
        attributes_table do
          row :id
          row :reimbursement do |work_order|
            link_to work_order.reimbursement.invoice_number, admin_reimbursement_path(work_order.reimbursement)
          end
          row :audit_work_order do |work_order|
            link_to work_order.audit_work_order.id, admin_audit_work_order_path(work_order.audit_work_order)
          end
          row :status do |work_order|
            status_tag work_order.status
          end
          row :communication_method
          row :initiator_role
          row :resolution_summary
          row :created_by
          row :created_at
          row :updated_at
        end
      end
      
      tab "沟通记录" do
        panel "沟通记录" do
          table_for resource.communication_records.order(recorded_at: :desc) do
            column :id
            column :communicator_role
            column :communicator_name
            column :communication_method
            column :content
            column :recorded_at
          end
        end
      end
      
      tab "费用明细" do
        panel "费用明细信息" do
          table_for resource.fee_details do
            column :id
            column :fee_type
            column :amount do |fee_detail|
              number_to_currency(fee_detail.amount, unit: "¥")
            end
            column :verification_status do |fee_detail|
              status_tag fee_detail.verification_status
            end
            column "验证状态" do |fee_detail|
              selection = resource.fee_detail_selections.find_by(fee_detail: fee_detail)
              status_tag selection.verification_status if selection.present?
            end
            column "操作" do |fee_detail|
              links = []
              links << link_to("查看", admin_fee_detail_path(fee_detail))
              links << link_to("解决问题", resolve_issue_admin_fee_detail_path(fee_detail, work_order_id: resource.id))
              links.join(" | ").html_safe
            end
          end
        end
      end
      
      tab "状态变更历史" do
        panel "状态变更历史" do
          table_for resource.work_order_status_changes.order(changed_at: :desc) do
            column :from_status
            column :to_status
            column :changed_at
            column :changed_by
          end
        end
      end
    end
  end
  
  # 表单
  form do |f|
    f.inputs "沟通工单信息" do
      f.input :reimbursement_id, as: :select, collection: Reimbursement.all.map { |r| [r.invoice_number, r.id] }
      f.input :audit_work_order_id, as: :select, collection: AuditWorkOrder.all.map { |w| [w.id, w.id] }
      f.input :status, as: :select, collection: ["open", "in_progress", "resolved", "unresolved", "closed"]
      f.input :communication_method, as: :select, collection: ["email", "phone", "system", "other"]
      f.input :initiator_role, as: :select, collection: ["auditor", "applicant", "manager", "other"]
      f.input :resolution_summary
      f.input :created_by, input_html: { value: current_admin_user.id }, as: :hidden
    end
    f.actions
  end
end
```

## 3. 自定义视图

### 3.1 报销单导入视图

```erb
<!-- app/views/admin/reimbursements/new_import.html.erb -->
<h2>导入报销单</h2>

<%= form_tag import_admin_reimbursements_path, multipart: true do %>
  <div class="panel">
    <div class="panel_contents">
      <div class="attributes_table">
        <table>
          <tr>
            <th>选择CSV文件</th>
            <td><%= file_field_tag :file, accept: '.csv' %></td>
          </tr>
        </table>
      </div>
    </div>
  </div>
  
  <div class="actions">
    <%= submit_tag "导入", class: "button" %>
    <%= link_to "取消", admin_reimbursements_path, class: "button" %>
  </div>
<% end %>

<div class="panel">
  <h3>导入说明</h3>
  <div class="panel_contents">
    <p>CSV文件应包含以下列：</p>
    <ul>
      <li>报销单单号（必填）</li>
      <li>单据名称</li>
      <li>报销单申请人</li>
      <li>报销单申请人工号</li>
      <li>申请人公司</li>
      <li>申请人部门</li>
      <li>报销金额（单据币种）</li>
      <li>收单状态</li>
      <li>报销单状态</li>
      <li>收单日期</li>
      <li>提交报销日期</li>
      <li>单据标签</li>
    </ul>
  </div>
</div>
```

### 3.2 审核工单审核视图

```erb
<!-- app/views/admin/audit_work_orders/approve.html.erb -->
<h2>审核通过</h2>

<%= form_tag do_approve_admin_audit_work_order_path(@audit_work_order), method: :post do %>
  <div class="panel">
    <div class="panel_contents">
      <div class="attributes_table">
        <table>
          <tr>
            <th>报销单号</th>
            <td><%= @audit_work_order.reimbursement.invoice_number %></td>
          </tr>
          <tr>
            <th>申请人</th>
            <td><%= @audit_work_order.reimbursement.applicant %></td>
          </tr>
          <tr>
            <th>审核意见</th>
            <td><%= text_area_tag :comment, nil, rows: 5, cols: 50 %></td>
          </tr>
        </table>
      </div>
    </div>
  </div>
  
  <div class="actions">
    <%= submit_tag "确认通过", class: "button" %>
    <%= link_to "取消", admin_audit_work_order_path(@audit_work_order), class: "button" %>
  </div>
<% end %>
```

### 3.3 沟通工单沟通记录视图

```erb
<!-- app/views/admin/communication_work_orders/new_communication_record.html.erb -->
<h2>添加沟通记录</h2>

<%= form_tag create_communication_record_admin_communication_work_order_path(@communication_work_order), method: :post do %>
  <div class="panel">
    <div class="panel_contents">
      <div class="attributes_table">
        <table>
          <tr>
            <th>沟通内容</th>
            <td><%= text_area_tag :content, nil, rows: 5, cols: 50, required: true %></td>
          </tr>
          <tr>
            <th>沟通角色</th>
            <td>
              <%= select_tag :communicator_role, options_for_select([
                ["审核人", "auditor"],
                ["申请人", "applicant"],
                ["管理员", "admin"],
                ["其他", "other"]
              ]), required: true %>
            </td>
          </tr>
          <tr>
            <th>沟通人姓名</th>
            <td><%= text_field_tag :communicator_name, current_admin_user.email %></td>
          </tr>
          <tr>
            <th>沟通方式</th>
            <td>
              <%= select_tag :communication_method, options_for_select([
                ["系统", "system"],
                ["邮件", "email"],
                ["电话", "phone"],
                ["其他", "other"]
              ]), required: true %>
            </td>
          </tr>
        </table>
      </div>
    </div>
  </div>
  
  <div class="actions">
    <%= submit_tag "添加记录", class: "button" %>
    <%= link_to "取消", admin_communication_work_order_path(@communication_work_order), class: "button" %>
  </div>
<% end %>
```