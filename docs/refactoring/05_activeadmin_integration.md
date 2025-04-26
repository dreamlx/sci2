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
    # 调用导入服务
    service = ReimbursementImportService.new(params[:file], current_admin_user)
    result = service.import
    if result[:success]
      redirect_to admin_reimbursements_path, notice: "导入成功: #{result[:created]} 创建, #{result[:updated]} 更新, #{result[:errors]} 错误."
    else
      # 错误处理，可能需要渲染 new_import 并显示错误
      redirect_to new_import_admin_reimbursements_path, alert: "导入失败: #{result[:errors].join(', ')}"
    end
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

      tab "快递收单工单" do
        panel "快递收单工单信息" do
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
              # 假设 admin_fee_detail_path 存在
              links << link_to("查看", admin_fee_detail_path(fee_detail))
              links.join(" | ").html_safe
            end
          end
        end
      end
    end
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
  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :tracking_number
  filter :status, as: :select, collection: ExpressReceiptWorkOrder.state_machines[:status].states.map(&:name)
  filter :received_at
  filter :created_at

  # 批量操作
  batch_action :process, if: proc { params[:scope] == 'received' || params[:q].blank? } do |ids|
    batch_action_collection.find(ids).each do |work_order|
      begin
        ExpressReceiptWorkOrderService.new(work_order, current_admin_user).process
      rescue StateMachines::InvalidTransition => e
        # 忽略无法转换的错误，或记录日志
        Rails.logger.warn "批量处理快递收单工单 ##{work_order.id} 失败: #{e.message}"
      end
    end
    redirect_to collection_path, notice: "已尝试将选中的工单标记为已处理"
  end

  batch_action :complete, if: proc { params[:scope] == 'processed' || params[:q].blank? } do |ids|
    batch_action_collection.find(ids).each do |work_order|
      begin
        ExpressReceiptWorkOrderService.new(work_order, current_admin_user).complete
      rescue StateMachines::InvalidTransition => e
        Rails.logger.warn "批量完成快递收单工单 ##{work_order.id} 失败: #{e.message}"
      end
    end
    redirect_to collection_path, notice: "已尝试将选中的工单标记为已完成"
  end

  # 自定义操作
  action_item :process, only: :show, if: proc { resource.may_process? } do
    link_to "处理", process_admin_express_receipt_work_order_path(resource), method: :put
  end

  action_item :complete, only: :show, if: proc { resource.may_complete? } do
    link_to "完成", complete_admin_express_receipt_work_order_path(resource), method: :put
  end

  # 自定义页面
  member_action :process, method: :put do
    service = ExpressReceiptWorkOrderService.new(resource, current_admin_user)
    begin
      if service.process
        redirect_to admin_express_receipt_work_order_path(resource), notice: "工单已处理"
      else
        redirect_to admin_express_receipt_work_order_path(resource), alert: "操作失败: #{resource.errors.full_messages.join(', ')}"
      end
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_express_receipt_work_order_path(resource), alert: "状态转换失败: #{e.message}"
    end
  end

  member_action :complete, method: :put do
    service = ExpressReceiptWorkOrderService.new(resource, current_admin_user)
    begin
      if service.complete
        redirect_to admin_express_receipt_work_order_path(resource), notice: "工单已完成，并已创建审核工单"
      else
        redirect_to admin_express_receipt_work_order_path(resource), alert: "操作失败: #{resource.errors.full_messages.join(', ')}"
      end
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_express_receipt_work_order_path(resource), alert: "状态转换失败: #{e.message}"
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
        column :changed_by do |change|
          AdminUser.find_by(id: change.changed_by)&.email
        end
      end
    end

    panel "关联的审核工单" do
      if resource.audit_work_order.present?
        attributes_table_for resource.audit_work_order do
          row :id do |audit_wo|
            link_to audit_wo.id, admin_audit_work_order_path(audit_wo)
          end
          row :status do |audit_wo|
            status_tag audit_wo.status
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
      f.input :status, as: :select, collection: ExpressReceiptWorkOrder.state_machines[:status].states.map(&:name)
      f.input :tracking_number
      f.input :received_at, as: :datepicker
      f.input :courier_name
      # f.input :created_by, input_html: { value: current_admin_user.id }, as: :hidden # created_by 应由服务层处理
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
  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :status, as: :select, collection: AuditWorkOrder.state_machines[:status].states.map(&:name)
  filter :audit_result, as: :select, collection: ["approved", "rejected"]
  filter :audit_date
  filter :created_at

  # 批量操作
  batch_action :start_processing, if: proc { params[:scope] == 'pending' || params[:q].blank? } do |ids|
    batch_action_collection.find(ids).each do |work_order|
      begin
        AuditWorkOrderService.new(work_order, current_admin_user).start_processing
      rescue StateMachines::InvalidTransition => e
        Rails.logger.warn "批量处理审核工单 ##{work_order.id} 失败: #{e.message}"
      end
    end
    redirect_to collection_path, notice: "已尝试将选中的工单标记为处理中"
  end

  # 自定义操作 (Action Items)
  action_item :start_processing, only: :show, if: proc { resource.may_start_processing? } do
    link_to "开始处理", start_processing_admin_audit_work_order_path(resource), method: :put
  end

  action_item :start_audit, only: :show, if: proc { resource.may_start_audit? } do
    link_to "开始审核", start_audit_admin_audit_work_order_path(resource), method: :put
  end

  action_item :approve, only: :show, if: proc { resource.may_approve? } do
    link_to "审核通过", approve_admin_audit_work_order_path(resource) # GET to show form
  end

  action_item :reject, only: :show, if: proc { resource.may_reject? } do # Handles both auditing and needs_communication
    link_to "审核拒绝", reject_admin_audit_work_order_path(resource) # GET to show form
  end

  action_item :need_communication, only: :show, if: proc { resource.may_need_communication? } do
    link_to "需要沟通", new_communication_admin_audit_work_order_path(resource) # GET to show form
  end

  action_item :complete, only: :show, if: proc { resource.may_complete? } do
    link_to "完成", complete_admin_audit_work_order_path(resource), method: :put
  end

  # 自定义页面 (Member Actions)
  member_action :start_processing, method: :put do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    begin
      service.start_processing
      redirect_to admin_audit_work_order_path(resource), notice: "工单已开始处理"
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_audit_work_order_path(resource), alert: "状态转换失败: #{e.message}"
    end
  end

  member_action :start_audit, method: :put do
    service = AuditWorkOrderService.new(resource, current_admin_user)
     begin
      service.start_audit
      redirect_to admin_audit_work_order_path(resource), notice: "工单已开始审核"
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_audit_work_order_path(resource), alert: "状态转换失败: #{e.message}"
    end
  end

  member_action :approve, method: :get do
    # Renders app/views/admin/audit_work_orders/approve.html.erb
    render :approve
  end

  member_action :do_approve, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    begin
      if service.approve(params[:comment])
        redirect_to admin_audit_work_order_path(resource), notice: "审核已通过"
      else
        # Re-render form with errors if service returns false
        flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
        render :approve
      end
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_audit_work_order_path(resource), alert: "状态转换失败: #{e.message}"
    end
  end

  member_action :reject, method: :get do
    # Renders app/views/admin/audit_work_orders/reject.html.erb
    render :reject
  end

  member_action :do_reject, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    begin
      if service.reject(params[:comment])
        redirect_to admin_audit_work_order_path(resource), notice: "审核已拒绝"
      else
        flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
        render :reject
      end
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_audit_work_order_path(resource), alert: "状态转换失败: #{e.message}"
    end
  end

  member_action :new_communication, method: :get do
    @fee_details = resource.reimbursement.fee_details.where(verification_status: ['pending', 'problematic']) # Only show relevant fee details
    # Renders app/views/admin/audit_work_orders/new_communication.html.erb
    render :new_communication
  end

  member_action :create_communication, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    communication_work_order = service.create_communication_work_order(
      communication_method: params[:communication_method],
      initiator_role: params[:initiator_role],
      content: params[:content],
      fee_detail_ids: params[:fee_detail_ids]
    )

    if communication_work_order&.persisted?
      redirect_to admin_communication_work_order_path(communication_work_order), notice: "沟通工单已创建"
    else
      errors = communication_work_order&.errors&.full_messages || resource.errors.full_messages
      flash.now[:alert] = "创建沟通工单失败: #{errors.join(', ')}"
      @fee_details = resource.reimbursement.fee_details.where(verification_status: ['pending', 'problematic'])
      render :new_communication
    end
  end

  member_action :complete, method: :put do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    begin
      service.complete
      redirect_to admin_audit_work_order_path(resource), notice: "工单已完成"
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_audit_work_order_path(resource), alert: "状态转换失败: #{e.message}"
    end
  end

  # Action for verifying a single fee detail
  member_action :verify_fee_detail, method: :get do
    @fee_detail = FeeDetail.find(params[:fee_detail_id])
    # Renders app/views/admin/audit_work_orders/verify_fee_detail.html.erb
    render :verify_fee_detail
  end

  member_action :do_verify_fee_detail, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    if service.verify_fee_detail(params[:fee_detail_id], params[:verification_status], params[:comment])
       redirect_to admin_audit_work_order_path(resource), notice: "费用明细 ##{params[:fee_detail_id]} 状态已更新"
    else
       @fee_detail = FeeDetail.find(params[:fee_detail_id]) # Need fee_detail for rendering form again
       flash.now[:alert] = "费用明细 ##{params[:fee_detail_id]} 更新失败: #{@fee_detail.errors.full_messages.join(', ')}"
       render :verify_fee_detail
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
          row :created_by do |work_order|
             AdminUser.find_by(id: work_order.created_by)&.email
          end
          row :created_at
          row :updated_at
        end
      end

      tab "费用明细" do
        panel "费用明细信息" do
          table_for resource.fee_detail_selections.includes(:fee_detail) do |selection|
            column "费用明细ID", :fee_detail_id do |sel|
              link_to sel.fee_detail_id, admin_fee_detail_path(sel.fee_detail)
            end
            column "费用类型", :fee_type do |sel|
              sel.fee_detail.fee_type
            end
            column "金额", :amount do |sel|
              number_to_currency(sel.fee_detail.amount, unit: "¥")
            end
            column "验证状态 (工单内)", :verification_status do |sel|
              status_tag sel.verification_status
            end
             column "验证状态 (全局)", :global_status do |sel|
              status_tag sel.fee_detail.verification_status
            end
            column "验证意见", :verification_comment
            column "操作" do |sel|
              links = []
              # Link to verify/reject/mark problematic within this AuditWorkOrder context
              links << link_to("更新验证状态", verify_fee_detail_admin_audit_work_order_path(resource, fee_detail_id: sel.fee_detail_id))
              # Link to create communication, pre-selecting this fee detail
              if resource.may_need_communication? && sel.verification_status != 'verified' && sel.verification_status != 'rejected'
                 links << link_to("创建沟通工单", new_communication_admin_audit_work_order_path(resource, fee_detail_ids: [sel.fee_detail_id]))
              end
              links.join(" | ").html_safe
            end
          end
        end
      end

      tab "沟通工单" do
        panel "沟通工单信息" do
          table_for resource.communication_work_orders do
            column :id do |comm_wo|
              link_to comm_wo.id, admin_communication_work_order_path(comm_wo)
            end
            column :status do |comm_wo|
              status_tag comm_wo.status
            end
            column :communication_method
            column :initiator_role
            column :created_at
          end
        end
      end

      tab "状态变更历史" do
        panel "状态变更历史" do
          table_for resource.work_order_status_changes.order(changed_at: :desc) do
            column :from_status
            column :to_status
            column :changed_at
            column :changed_by do |change|
              AdminUser.find_by(id: change.changed_by)&.email
            end
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
      f.input :status, as: :select, collection: AuditWorkOrder.state_machines[:status].states.map(&:name)
      f.input :audit_result, as: :select, collection: ["approved", "rejected"]
      f.input :audit_comment
      f.input :audit_date, as: :datepicker
      f.input :vat_verified
      # f.input :created_by, input_html: { value: current_admin_user.id }, as: :hidden # Should be handled by service/controller
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
  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :audit_work_order_id
  filter :status, as: :select, collection: CommunicationWorkOrder.state_machines[:status].states.map(&:name)
  filter :communication_method
  filter :initiator_role
  filter :created_at

  # 自定义操作
  action_item :start_communication, only: :show, if: proc { resource.may_start_communication? } do
    link_to "开始沟通", start_communication_admin_communication_work_order_path(resource), method: :put
  end

  action_item :add_communication_record, only: :show, if: proc { resource.may_add_communication_record? } do # Assuming may_add_communication_record? exists or based on status
    link_to "添加沟通记录", new_communication_record_admin_communication_work_order_path(resource)
  end

  action_item :resolve, only: :show, if: proc { resource.may_resolve? } do
    link_to "标记已解决", resolve_admin_communication_work_order_path(resource) # GET to show form
  end

  action_item :mark_unresolved, only: :show, if: proc { resource.may_mark_unresolved? } do
    link_to "标记未解决", mark_unresolved_admin_communication_work_order_path(resource) # GET to show form
  end

  action_item :close, only: :show, if: proc { resource.may_close? } do
    link_to "关闭", close_admin_communication_work_order_path(resource), method: :put
  end

  # 自定义页面
  member_action :start_communication, method: :put do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    begin
      service.start_communication
      redirect_to admin_communication_work_order_path(resource), notice: "工单已开始沟通"
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_communication_work_order_path(resource), alert: "状态转换失败: #{e.message}"
    end
  end

  member_action :new_communication_record, method: :get do
    # Renders app/views/admin/communication_work_orders/new_communication_record.html.erb
    render :new_communication_record
  end

  member_action :create_communication_record, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    communication_record = service.add_communication_record(params.require(:communication_record).permit(:content, :communicator_role, :communicator_name, :communication_method))

    if communication_record.persisted?
      redirect_to admin_communication_work_order_path(resource), notice: "沟通记录已添加"
    else
      flash.now[:alert] = "添加沟通记录失败: #{communication_record.errors.full_messages.join(', ')}"
      render :new_communication_record
    end
  end

  member_action :resolve, method: :get do
    # Renders app/views/admin/communication_work_orders/resolve.html.erb
    render :resolve
  end

  member_action :do_resolve, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    begin
      if service.resolve(params[:resolution_summary])
        redirect_to admin_communication_work_order_path(resource), notice: "工单已标记为已解决"
      else
        flash.now[:alert] = "操作失败"
        render :resolve
      end
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_communication_work_order_path(resource), alert: "状态转换失败: #{e.message}"
    end
  end

  member_action :mark_unresolved, method: :get do
    # Renders app/views/admin/communication_work_orders/mark_unresolved.html.erb
    render :mark_unresolved
  end

  member_action :do_mark_unresolved, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    begin
      if service.mark_unresolved(params[:resolution_summary])
        redirect_to admin_communication_work_order_path(resource), notice: "工单已标记为未解决"
      else
         flash.now[:alert] = "操作失败"
         render :mark_unresolved
      end
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_communication_work_order_path(resource), alert: "状态转换失败: #{e.message}"
    end
  end

  member_action :close, method: :put do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    begin
      service.close
      redirect_to admin_communication_work_order_path(resource), notice: "工单已关闭"
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_communication_work_order_path(resource), alert: "状态转换失败: #{e.message}"
    end
  end

  # Action for resolving a fee detail issue (updates comment only)
  member_action :resolve_fee_detail_issue, method: :get do
     @fee_detail = FeeDetail.find(params[:fee_detail_id])
     # Renders app/views/admin/communication_work_orders/resolve_fee_detail_issue.html.erb
     render :resolve_fee_detail_issue
  end

  member_action :do_resolve_fee_detail_issue, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    if service.resolve_fee_detail_issue(params[:fee_detail_id], params[:resolution])
      redirect_to admin_communication_work_order_path(resource), notice: "费用明细 ##{params[:fee_detail_id]} 问题备注已更新"
    else
      @fee_detail = FeeDetail.find(params[:fee_detail_id])
      flash.now[:alert] = "更新费用明细备注失败"
      render :resolve_fee_detail_issue
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
          row :created_by do |work_order|
             AdminUser.find_by(id: work_order.created_by)&.email
          end
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

      tab "关联费用明细" do
        panel "费用明细信息" do
          table_for resource.fee_detail_selections.includes(:fee_detail) do |selection|
             column "费用明细ID", :fee_detail_id do |sel|
              link_to sel.fee_detail_id, admin_fee_detail_path(sel.fee_detail)
            end
            column "费用类型", :fee_type do |sel|
              sel.fee_detail.fee_type
            end
            column "金额", :amount do |sel|
              number_to_currency(sel.fee_detail.amount, unit: "¥")
            end
            column "验证状态 (工单内)", :verification_status do |sel|
              status_tag sel.verification_status # Should always be 'problematic' here
            end
             column "验证状态 (全局)", :global_status do |sel|
              status_tag sel.fee_detail.verification_status
            end
            column "验证意见", :verification_comment
            column "操作" do |sel|
              links = []
              # Link to add/update resolution comment for this fee detail within this communication work order
              links << link_to("添加/更新解决备注", resolve_fee_detail_issue_admin_communication_work_order_path(resource, fee_detail_id: sel.fee_detail_id))
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
            column :changed_by do |change|
              AdminUser.find_by(id: change.changed_by)&.email
            end
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
      f.input :status, as: :select, collection: CommunicationWorkOrder.state_machines[:status].states.map(&:name)
      f.input :communication_method, as: :select, collection: ["email", "phone", "system", "other"]
      f.input :initiator_role, as: :select, collection: ["auditor", "applicant", "manager", "other"]
      f.input :resolution_summary
      # f.input :created_by, input_html: { value: current_admin_user.id }, as: :hidden # Should be handled by service/controller
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
            <th>选择文件</th>
            <td><%= file_field_tag :file, accept: '.csv,.xlsx,.xls', required: true %></td>
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
    <p>CSV或Excel文件应包含以下列：</p>
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
<% provide :title, "审核通过 - 审核工单 ##{@audit_work_order.id}" %>
<h2>审核通过 - 审核工单 #<%= @audit_work_order.id %></h2>

<%= semantic_form_for @audit_work_order, url: do_approve_admin_audit_work_order_path(@audit_work_order), method: :post do |f| %>
  <%= f.inputs do %>
    <li class="string input optional">
      <label class="label">报销单号</label>
      <%= link_to @audit_work_order.reimbursement.invoice_number, admin_reimbursement_path(@audit_work_order.reimbursement) %>
    </li>
     <li class="string input optional">
      <label class="label">申请人</label>
      <%= @audit_work_order.reimbursement.applicant %>
    </li>
    <%= f.input :comment, as: :text, label: "审核意见", input_html: { rows: 5 } %>
  <% end %>
  <%= f.actions do %>
    <%= f.action :submit, label: "确认通过", button_html: { class: "button" } %>
    <%= f.action :cancel, label: "取消", wrapper_html: { class: 'cancel' }, button_html: { type: 'link', href: admin_audit_work_order_path(@audit_work_order) } %>
  <% end %>
<% end %>

<!-- app/views/admin/audit_work_orders/reject.html.erb -->
<% provide :title, "审核拒绝 - 审核工单 ##{@audit_work_order.id}" %>
<h2>审核拒绝 - 审核工单 #<%= @audit_work_order.id %></h2>

<%= semantic_form_for @audit_work_order, url: do_reject_admin_audit_work_order_path(@audit_work_order), method: :post do |f| %>
  <%= f.inputs do %>
     <li class="string input optional">
      <label class="label">报销单号</label>
      <%= link_to @audit_work_order.reimbursement.invoice_number, admin_reimbursement_path(@audit_work_order.reimbursement) %>
    </li>
     <li class="string input optional">
      <label class="label">申请人</label>
      <%= @audit_work_order.reimbursement.applicant %>
    </li>
    <%= f.input :comment, as: :text, label: "审核意见 (必填)", input_html: { rows: 5, required: true } %>
  <% end %>
  <%= f.actions do %>
    <%= f.action :submit, label: "确认拒绝", button_html: { class: "button" } %>
    <%= f.action :cancel, label: "取消", wrapper_html: { class: 'cancel' }, button_html: { type: 'link', href: admin_audit_work_order_path(@audit_work_order) } %>
  <% end %>
<% end %>

<!-- app/views/admin/audit_work_orders/new_communication.html.erb -->
<% provide :title, "创建沟通工单 - 审核工单 ##{@audit_work_order.id}" %>
<h2>创建沟通工单 - 审核工单 #<%= @audit_work_order.id %></h2>

<%= semantic_form_for :communication_work_order, url: create_communication_admin_audit_work_order_path(@audit_work_order), method: :post do |f| %>
  <%= f.inputs do %>
    <%= f.input :communication_method, as: :select, collection: ["email", "phone", "system", "other"], label: "沟通方式", required: true %>
    <%= f.input :initiator_role, as: :select, collection: ["auditor", "applicant", "manager", "other"], label: "发起人角色", required: true %>
    <%= f.input :content, as: :text, label: "沟通内容/问题描述", input_html: { rows: 5, required: true } %>
    <%= f.input :fee_detail_ids, as: :check_boxes, collection: @fee_details.map { |fd| ["##{fd.id} - #{fd.fee_type} (#{number_to_currency(fd.amount)})", fd.id] }, label: "关联费用明细 (可选)" %>
  <% end %>
  <%= f.actions do %>
    <%= f.action :submit, label: "创建沟通工单", button_html: { class: "button" } %>
    <%= f.action :cancel, label: "取消", wrapper_html: { class: 'cancel' }, button_html: { type: 'link', href: admin_audit_work_order_path(@audit_work_order) } %>
  <% end %>
<% end %>

<!-- app/views/admin/audit_work_orders/verify_fee_detail.html.erb -->
<% provide :title, "验证费用明细 ##{@fee_detail.id} - 审核工单 ##{@audit_work_order.id}" %>
<h2>验证费用明细 #<%= @fee_detail.id %> - 审核工单 #<%= @audit_work_order.id %></h2>

<%= semantic_form_for @audit_work_order, url: do_verify_fee_detail_admin_audit_work_order_path(@audit_work_order), method: :post do |f| %>
  <%= hidden_field_tag :fee_detail_id, @fee_detail.id %>
  <%= f.inputs do %>
    <li class="string input optional">
      <label class="label">费用类型</label>
      <%= @fee_detail.fee_type %>
    </li>
    <li class="string input optional">
      <label class="label">金额</label>
      <%= number_to_currency(@fee_detail.amount, unit: "¥") %>
    </li>
    <li class="string input optional">
      <label class="label">当前全局状态</label>
      <%= status_tag @fee_detail.verification_status %>
    </li>
    <% selection = @audit_work_order.fee_detail_selections.find_by(fee_detail_id: @fee_detail.id) %>
    <li class="string input optional">
      <label class="label">当前工单内状态</label>
      <%= status_tag selection&.verification_status %>
    </li>
    <%= f.input :verification_status, as: :select, collection: [["已验证", "verified"], ["已拒绝", "rejected"], ["有问题", "problematic"]], label: "设置验证状态", required: true, selected: selection&.verification_status %>
    <%= f.input :comment, as: :text, label: "验证意见", input_html: { rows: 3, value: selection&.verification_comment } %>
  <% end %>
  <%= f.actions do %>
    <%= f.action :submit, label: "提交", button_html: { class: "button" } %>
    <%= f.action :cancel, label: "取消", wrapper_html: { class: 'cancel' }, button_html: { type: 'link', href: admin_audit_work_order_path(@audit_work_order) } %>
  <% end %>
<% end %>

```

### 3.3 沟通工单沟通记录视图

```erb
<!-- app/views/admin/communication_work_orders/new_communication_record.html.erb -->
<% provide :title, "添加沟通记录 - 沟通工单 ##{@communication_work_order.id}" %>
<h2>添加沟通记录 - 沟通工单 #<%= @communication_work_order.id %></h2>

<%= semantic_form_for :communication_record, url: create_communication_record_admin_communication_work_order_path(@communication_work_order), method: :post do |f| %>
  <%= f.inputs do %>
    <%= f.input :content, as: :text, label: "沟通内容", input_html: { rows: 5, required: true } %>
    <%= f.input :communicator_role, as: :select, collection: [["审核人", "auditor"], ["申请人", "applicant"], ["管理员", "admin"], ["其他", "other"]], label: "沟通角色", required: true %>
    <%= f.input :communicator_name, as: :string, label: "沟通人姓名", input_html: { value: current_admin_user.email } %>
    <%= f.input :communication_method, as: :select, collection: [["系统", "system"], ["邮件", "email"], ["电话", "phone"], ["其他", "other"]], label: "沟通方式", required: true %>
  <% end %>
  <%= f.actions do %>
    <%= f.action :submit, label: "添加记录", button_html: { class: "button" } %>
    <%= f.action :cancel, label: "取消", wrapper_html: { class: 'cancel' }, button_html: { type: 'link', href: admin_communication_work_order_path(@communication_work_order) } %>
  <% end %>
<% end %>

<!-- app/views/admin/communication_work_orders/resolve.html.erb -->
<% provide :title, "标记已解决 - 沟通工单 ##{@communication_work_order.id}" %>
<h2>标记已解决 - 沟通工单 #<%= @communication_work_order.id %></h2>

<%= semantic_form_for @communication_work_order, url: do_resolve_admin_communication_work_order_path(@communication_work_order), method: :post do |f| %>
  <%= f.inputs do %>
    <%= f.input :resolution_summary, as: :text, label: "解决摘要", input_html: { rows: 5 } %>
  <% end %>
  <%= f.actions do %>
    <%= f.action :submit, label: "确认已解决", button_html: { class: "button" } %>
    <%= f.action :cancel, label: "取消", wrapper_html: { class: 'cancel' }, button_html: { type: 'link', href: admin_communication_work_order_path(@communication_work_order) } %>
  <% end %>
<% end %>

<!-- app/views/admin/communication_work_orders/mark_unresolved.html.erb -->
<% provide :title, "标记未解决 - 沟通工单 ##{@communication_work_order.id}" %>
<h2>标记未解决 - 沟通工单 #<%= @communication_work_order.id %></h2>

<%= semantic_form_for @communication_work_order, url: do_mark_unresolved_admin_communication_work_order_path(@communication_work_order), method: :post do |f| %>
  <%= f.inputs do %>
    <%= f.input :resolution_summary, as: :text, label: "未解决原因/摘要", input_html: { rows: 5 } %>
  <% end %>
  <%= f.actions do %>
    <%= f.action :submit, label: "确认未解决", button_html: { class: "button" } %>
    <%= f.action :cancel, label: "取消", wrapper_html: { class: 'cancel' }, button_html: { type: 'link', href: admin_communication_work_order_path(@communication_work_order) } %>
  <% end %>
<% end %>

<!-- app/views/admin/communication_work_orders/resolve_fee_detail_issue.html.erb -->
<% provide :title, "解决费用明细问题备注 - 沟通工单 ##{@communication_work_order.id}" %>
<h2>解决费用明细问题备注 - 沟通工单 #<%= @communication_work_order.id %></h2>
<h3>费用明细 #<%= @fee_detail.id %></h3>

<%= semantic_form_for @communication_work_order, url: do_resolve_fee_detail_issue_admin_communication_work_order_path(@communication_work_order), method: :post do |f| %>
  <%= hidden_field_tag :fee_detail_id, @fee_detail.id %>
  <%= f.inputs do %>
     <li class="string input optional">
      <label class="label">费用类型</label>
      <%= @fee_detail.fee_type %>
    </li>
    <li class="string input optional">
      <label class="label">金额</label>
      <%= number_to_currency(@fee_detail.amount, unit: "¥") %>
    </li>
    <% selection = @communication_work_order.fee_detail_selections.find_by(fee_detail_id: @fee_detail.id) %>
     <li class="string input optional">
      <label class="label">当前备注</label>
      <%= selection&.verification_comment %>
    </li>
    <%= f.input :resolution, as: :text, label: "解决备注", input_html: { rows: 5, value: selection&.verification_comment } %>
  <% end %>
  <%= f.actions do %>
    <%= f.action :submit, label: "更新备注", button_html: { class: "button" } %>
    <%= f.action :cancel, label: "取消", wrapper_html: { class: 'cancel' }, button_html: { type: 'link', href: admin_communication_work_order_path(@communication_work_order) } %>
  <% end %>
<% end %>