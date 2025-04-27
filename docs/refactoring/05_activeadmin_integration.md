# SCI2 工单系统ActiveAdmin集成 (STI 版本 - v2)

## 1. ActiveAdmin概述

ActiveAdmin将用于实现管理界面。本次重构采用STI模型，ActiveAdmin的集成需要相应调整。

### 1.1 ActiveAdmin配置

*(No changes needed)*

```ruby
# config/initializers/active_admin.rb
ActiveAdmin.setup do |config|
  config.site_title = "SCI2工单系统"
  config.default_namespace = :admin
  config.root_to = 'dashboard#index'
  config.batch_actions = true
  config.default_per_page = 30
  config.csv_options = { col_sep: ',', force_quotes: true }
  config.filters_position = :right
  config.comments = false # Assuming comments are not needed
end
```

## 2. 资源注册 (STI)

为每个主要模型（包括 `WorkOrder` 子类）注册单独的 ActiveAdmin 资源。

### 2.1 报销单资源 (Reimbursement)

*   添加 `external_status`, `approval_date`, `approver_name`。
*   更新状态过滤和显示。

```ruby
# app/admin/reimbursements.rb
ActiveAdmin.register Reimbursement do
  permit_params :invoice_number, :document_name, :applicant, :applicant_id, :company, :department,
                :amount, :receipt_status, :status, :receipt_date, :submission_date,
                :is_electronic, :external_status, :approval_date, :approver_name # Added fields

  menu priority: 1, label: "报销单管理"

  filter :invoice_number
  filter :applicant
  filter :status, label: "内部状态", as: :select, collection: Reimbursement.state_machines[:status].states.map(&:value) # Use .value for state machine states
  filter :external_status, label: "外部状态"
  filter :receipt_status, as: :select, collection: ["pending", "received"]
  filter :is_electronic, as: :boolean
  filter :created_at
  filter :approval_date

  # Batch actions
  batch_action :mark_as_received do |ids|
     batch_action_collection.find(ids).each do |reimbursement|
        reimbursement.update(receipt_status: 'received', receipt_date: Time.current)
     end
     redirect_to collection_path, notice: "已将选中的报销单标记为已收单"
  end
  batch_action :start_processing, if: proc { params[:scope] == 'pending' || params[:q].blank? } do |ids|
     batch_action_collection.find(ids).each do |reimbursement|
        begin
          reimbursement.start_processing!
        rescue StateMachines::InvalidTransition => e
          Rails.logger.warn "Batch action start_processing failed for Reimbursement #{reimbursement.id}: #{e.message}"
        end
     end
     redirect_to collection_path, notice: "已尝试将选中的报销单标记为处理中"
  end


  action_item :import, only: :index do
    link_to "导入报销单", new_import_admin_reimbursements_path
  end
  action_item :new_audit_work_order, only: :show, if: proc{!resource.closed?} do # Only allow if not closed
    link_to "新建审核工单", new_admin_audit_work_order_path(reimbursement_id: resource.id)
  end
  action_item :new_communication_work_order, only: :show, if: proc{!resource.closed?} do # Only allow if not closed
     link_to "新建沟通工单", new_admin_communication_work_order_path(reimbursement_id: resource.id)
  end

  # Import actions
  collection_action :new_import, method: :get do
    render "admin/reimbursements/new_import" # Ensure this view exists
  end

  collection_action :import, method: :post do
    # Ensure file parameter exists
    unless params[:file].present?
       redirect_to new_import_admin_reimbursements_path, alert: "请选择要导入的文件。"
       return
    end
    service = ReimbursementImportService.new(params[:file], current_admin_user)
    result = service.import
    if result[:success]
      notice_message = "导入成功: #{result[:created]} 创建, #{result[:updated]} 更新."
      notice_message += " #{result[:errors]} 错误." if result[:errors].to_i > 0
      redirect_to admin_reimbursements_path, notice: notice_message
    else
      alert_message = "导入失败: #{result[:errors].join(', ')}"
      alert_message += " 错误详情: #{result[:error_details].join('; ')}" if result[:error_details].present?
      redirect_to new_import_admin_reimbursements_path, alert: alert_message
    end
  end

  index do
    selectable_column
    id_column
    column :invoice_number
    column :applicant
    column :amount do |reimbursement| number_to_currency(reimbursement.amount, unit: "¥") end
    column "内部状态", :status do |reimbursement| status_tag reimbursement.status end
    column "外部状态", :external_status
    column :receipt_status do |reimbursement| status_tag reimbursement.receipt_status end
    column :is_electronic
    column :approval_date
    column :created_at
    actions
  end

  show title: proc{|r| "报销单 ##{r.invoice_number}" } do
    tabs do
      tab "基本信息" do
        attributes_table do
          row :id
          row :invoice_number
          row :document_name
          row :applicant
          row :applicant_id
          row :company
          row :department
          row :amount do |reimbursement| number_to_currency(reimbursement.amount, unit: "¥") end
          row "内部状态", :status do |reimbursement| status_tag reimbursement.status end
          row "外部状态", :external_status
          row :receipt_status do |reimbursement| status_tag reimbursement.receipt_status end
          row :receipt_date
          row :submission_date
          row :is_electronic
          row :approval_date
          row :approver_name
          row :created_at
          row :updated_at
        end
      end

      tab "快递收单工单" do
        panel "快递收单工单信息" do
          table_for resource.express_receipt_work_orders.order(created_at: :desc) do
            column(:id) { |wo| link_to wo.id, admin_express_receipt_work_order_path(wo) }
            column :tracking_number
            column :received_at
            column :courier_name
            column(:status) { |wo| status_tag wo.status }
            column :creator
            column :created_at
          end
        end
      end

      tab "审核工单" do
        panel "审核工单信息" do
          table_for resource.audit_work_orders.order(created_at: :desc) do
            column(:id) { |wo| link_to wo.id, admin_audit_work_order_path(wo) }
            column(:status) { |wo| status_tag wo.status }
            column(:audit_result) { |wo| status_tag wo.audit_result if wo.audit_result.present? }
            column :audit_date
            column :creator
            column :created_at
          end
        end
         div class: "action_items" do
            span class: "action_item" do
              link_to "新建审核工单", new_admin_audit_work_order_path(reimbursement_id: resource.id), class: "button"
            end
         end
      end

      tab "沟通工单" do
        panel "沟通工单信息" do
          table_for resource.communication_work_orders.order(created_at: :desc) do
             column(:id) { |wo| link_to wo.id, admin_communication_work_order_path(wo) }
             column(:status) { |wo| status_tag wo.status }
             column :initiator_role
             column :creator
             column :created_at
          end
        end
         div class: "action_items" do
            span class: "action_item" do
              link_to "新建沟通工单", new_admin_communication_work_order_path(reimbursement_id: resource.id), class: "button"
            end
         end
      end

      tab "费用明细" do
        panel "费用明细信息" do
          table_for resource.fee_details.order(created_at: :desc) do
            column(:id) { |fd| link_to fd.id, admin_fee_detail_path(fd) } # Assuming FeeDetail resource exists
            column :fee_type
            column :amount do |fd| number_to_currency(fd.amount, unit: "¥") end
            column :fee_date
            column :verification_status do |fd| status_tag fd.verification_status end
            column :payment_method
            column :created_at
          end
        end
      end

       tab "操作历史" do
         panel "操作历史记录" do
           table_for resource.operation_histories.order(operation_time: :desc) do
             column :id
             column :operation_type
             column :operator
             column :operation_time
             column :notes
           end
         end
       end
    end
    active_admin_comments # Optional: If you want comments on Reimbursement
  end

  form do |f|
    f.inputs "报销单信息" do
      f.input :invoice_number, input_html: { readonly: !f.object.new_record? } # Readonly if editing
      f.input :document_name
      f.input :applicant
      f.input :applicant_id
      f.input :company
      f.input :department
      f.input :amount
      f.input :status, label: "内部状态", as: :select, collection: Reimbursement.state_machines[:status].states.map(&:value), include_blank: false # Allow manual change?
      f.input :external_status, label: "外部状态", input_html: { readonly: true } # Readonly
      f.input :receipt_status, as: :select, collection: ["pending", "received"]
      f.input :receipt_date, as: :datepicker
      f.input :submission_date, as: :datepicker
      f.input :is_electronic
      f.input :approval_date, as: :datepicker
      f.input :approver_name
    end
    f.actions
  end
end
```

### 2.2 快递收单工单资源 (ExpressReceiptWorkOrder)

*(No significant changes needed from v1)*

```ruby
# app/admin/express_receipt_work_orders.rb
ActiveAdmin.register ExpressReceiptWorkOrder do
  permit_params :reimbursement_id, :tracking_number, :received_at, :courier_name, :created_by

  menu priority: 2, label: "快递收单工单", parent: "工单管理" # Example parent menu

  controller do
    def scoped_collection
      # Ensure we only query for this specific type
      ExpressReceiptWorkOrder.includes(:reimbursement, :creator)
    end
  end

  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :tracking_number
  filter :received_at
  filter :courier_name
  filter :creator # Filter by creator (AdminUser)
  filter :created_at

  index do
    selectable_column
    id_column
    column :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
    column :tracking_number
    column :status do |wo| status_tag wo.status end # Always 'completed'
    column :received_at
    column :courier_name
    column :creator
    column :created_at
    actions
  end

  show title: proc{|wo| "快递收单工单 ##{wo.id}" } do
    attributes_table do
      row :id
      row :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
      row :type
      row :status do |wo| status_tag wo.status end
      row :tracking_number
      row :received_at
      row :courier_name
      row :creator
      row :created_at
      row :updated_at
    end

    panel "状态变更历史" do
       table_for resource.work_order_status_changes.order(changed_at: :desc) do
         column :from_status
         column :to_status
         column :changed_at
         column :changer do |change| change.changer&.email end # Display changer email
       end
    end
    active_admin_comments
  end

  form do |f|
    f.inputs "快递收单工单信息" do
      f.input :reimbursement_id, as: :select, collection: Reimbursement.all.map { |r| [r.invoice_number, r.id] }, input_html: { disabled: !f.object.new_record? }
      # Status is fixed, no input needed
      f.input :tracking_number
      f.input :received_at, as: :datepicker
      f.input :courier_name
      # created_by should be set automatically by service
    end
    f.actions
  end
end
```

### 2.3 审核工单资源 (AuditWorkOrder)

*   Add shared Req 6/7 fields to `permit_params`, form, show page.
*   Update member actions to pass shared fields.

```ruby
# app/admin/audit_work_orders.rb
ActiveAdmin.register AuditWorkOrder do
  permit_params :reimbursement_id, :status, :audit_result, :audit_comment, :audit_date,
                :vat_verified, :created_by,
                # Shared fields from Req 6/7
                :problem_type, :problem_description, :remark, :processing_opinion,
                fee_detail_ids: []

  menu priority: 3, label: "审核工单", parent: "工单管理"
  config.sort_order = 'created_at_desc'

  controller do
    def scoped_collection
      AuditWorkOrder.includes(:reimbursement, :creator) # Eager load common associations
    end

    # Set reimbursement based on param when creating
    def build_new_resource
      resource = super
      if params[:reimbursement_id] && resource.reimbursement_id.nil?
        resource.reimbursement_id = params[:reimbursement_id]
      end
      resource
    end
  end

  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :status, as: :select, collection: AuditWorkOrder.state_machines[:status].states.map(&:value)
  filter :audit_result, as: :select, collection: ["approved", "rejected"]
  filter :creator # Filter by creator (AdminUser)
  filter :created_at

  # Batch Actions
  batch_action :start_processing, if: proc { params[:scope] == 'pending' || params[:q].blank? } do |ids|
    batch_action_collection.find(ids).each do |work_order|
      begin
        AuditWorkOrderService.new(work_order, current_admin_user).start_processing
      rescue => e
         Rails.logger.warn "Batch action start_processing failed for AuditWorkOrder #{work_order.id}: #{e.message}"
      end
    end
    redirect_to collection_path, notice: "已尝试将选中的工单标记为处理中"
  end

  # Action Items
  action_item :start_processing, only: :show, if: proc { resource.pending? } do
    link_to "开始处理", start_processing_admin_audit_work_order_path(resource), method: :put, data: { confirm: "确定要开始处理此工单吗?" }
  end
  action_item :approve, only: :show, if: proc { resource.processing? } do
    link_to "审核通过", approve_admin_audit_work_order_path(resource)
  end
  action_item :reject, only: :show, if: proc { resource.processing? } do
    link_to "审核拒绝", reject_admin_audit_work_order_path(resource)
  end

  # Member Actions
  member_action :start_processing, method: :put do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    if service.start_processing
      redirect_to admin_audit_work_order_path(resource), notice: "工单已开始处理"
    else
      redirect_to admin_audit_work_order_path(resource), alert: "操作失败: #{resource.errors.full_messages.join(', ')}"
    end
  end

  member_action :approve, method: :get do
    @audit_work_order = resource
    render :approve # Renders app/views/admin/audit_work_orders/approve.html.erb
  end

  member_action :do_approve, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    permitted_params = params.require(:audit_work_order).permit(:audit_comment, :problem_type, :problem_description, :remark, :processing_opinion)
    if service.approve(permitted_params)
      redirect_to admin_audit_work_order_path(resource), notice: "审核已通过"
    else
      @audit_work_order = resource # Reassign for form rendering
      flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
      render :approve
    end
  end

  member_action :reject, method: :get do
    @audit_work_order = resource
    render :reject # Renders app/views/admin/audit_work_orders/reject.html.erb
  end

  member_action :do_reject, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    permitted_params = params.require(:audit_work_order).permit(:audit_comment, :problem_type, :problem_description, :remark, :processing_opinion)
    if service.reject(permitted_params)
      redirect_to admin_audit_work_order_path(resource), notice: "审核已拒绝"
    else
       @audit_work_order = resource # Reassign for form rendering
      flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
      render :reject
    end
  end

  # Fee Detail Verification Actions
  member_action :verify_fee_detail, method: :get do
     @work_order = resource # For shared view context
     @fee_detail = resource.fee_details.find(params[:fee_detail_id])
     render 'admin/shared/verify_fee_detail' # Renders app/views/admin/shared/verify_fee_detail.html.erb
  end

  member_action :do_verify_fee_detail, method: :post do
    service = AuditWorkOrderService.new(resource, current_admin_user)
    # Use params directly as they are not nested under audit_work_order
    if service.update_fee_detail_verification(params[:fee_detail_id], params[:verification_status], params[:comment])
       redirect_to admin_audit_work_order_path(resource), notice: "费用明细 ##{params[:fee_detail_id]} 状态已更新"
    else
       @work_order = resource
       @fee_detail = resource.fee_details.find(params[:fee_detail_id])
       flash.now[:alert] = "费用明细 ##{params[:fee_detail_id]} 更新失败: #{@fee_detail.errors.full_messages.join(', ')}"
       render 'admin/shared/verify_fee_detail'
    end
  end

  # Index Page
  index do
    selectable_column
    id_column
    column :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
    column :status do |wo| status_tag wo.status end
    column :audit_result do |wo| status_tag wo.audit_result if wo.audit_result.present? end
    column :creator
    column :created_at
    actions
  end

  # Show Page
  show title: proc{|wo| "审核工单 ##{wo.id}" } do
    tabs do
      tab "基本信息" do
        attributes_table do
          row :id
          row :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
          row :type
          row :status do |wo| status_tag wo.status end
          row :audit_result do |wo| status_tag wo.audit_result if wo.audit_result.present? end
          row :audit_comment
          row :audit_date
          row :vat_verified
          # Show Shared Req 6/7 fields
          row :problem_type
          row :problem_description
          row :remark
          row :processing_opinion
          row :creator
          row :created_at
          row :updated_at
        end
      end

      tab "费用明细 (#{resource.fee_details.count})" do
        panel "费用明细信息" do
          table_for resource.fee_detail_selections.includes(:fee_detail) do |selection|
            column "费用明细ID", :fee_detail_id do |sel| link_to sel.fee_detail_id, admin_fee_detail_path(sel.fee_detail) end
            column "费用类型", :fee_type do |sel| sel.fee_detail.fee_type end
            column "金额", :amount do |sel| number_to_currency(sel.fee_detail.amount, unit: "¥") end
            column "全局状态", :global_status do |sel| status_tag sel.fee_detail.verification_status end
            column "工单内状态", :verification_status do |sel| status_tag sel.verification_status end
            column "验证意见", :verification_comment
            column "操作" do |sel|
              link_to("更新验证状态", verify_fee_detail_admin_audit_work_order_path(resource, fee_detail_id: sel.fee_detail_id))
            end
          end
        end
      end

      tab "沟通工单 (#{resource.communication_work_orders.count})" do
         panel "关联沟通工单" do
            table_for resource.communication_work_orders do
                column(:id) { |comm_wo| link_to comm_wo.id, admin_communication_work_order_path(comm_wo) }
                column(:status) { |comm_wo| status_tag comm_wo.status }
                column :creator
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
             column :changer do |change| change.changer&.email end
           end
         end
      end
    end
    active_admin_comments
  end

  # Form - Use partial
  form partial: 'form'

end
```

### 2.4 沟通工单资源 (CommunicationWorkOrder)

*   Add shared Req 6/7 fields to `permit_params`, form, show page.
*   Update member actions to pass shared fields.

```ruby
# app/admin/communication_work_orders.rb
ActiveAdmin.register CommunicationWorkOrder do
  permit_params :reimbursement_id, :audit_work_order_id, :status, :communication_method,
                :initiator_role, :resolution_summary, :created_by,
                # Shared fields from Req 6/7
                :problem_type, :problem_description, :remark, :processing_opinion,
                fee_detail_ids: []

  menu priority: 4, label: "沟通工单", parent: "工单管理"
  config.sort_order = 'created_at_desc'

  controller do
    def scoped_collection
      CommunicationWorkOrder.includes(:reimbursement, :creator, :audit_work_order)
    end

    # Set reimbursement/audit_work_order based on param when creating
    def build_new_resource
      resource = super
      if params[:reimbursement_id] && resource.reimbursement_id.nil?
        resource.reimbursement_id = params[:reimbursement_id]
      end
      # Require audit_work_order_id for creation based on Req 5/7
      if params[:audit_work_order_id] && resource.audit_work_order_id.nil?
         resource.audit_work_order_id = params[:audit_work_order_id]
      end
      resource
    end
  end

  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :audit_work_order_id
  filter :status, as: :select, collection: CommunicationWorkOrder.state_machines[:status].states.map(&:value)
  filter :communication_method
  filter :initiator_role
  filter :creator
  filter :created_at

  # Action Items
  action_item :start_processing, only: :show, if: proc { resource.pending? } do
    link_to "开始处理", start_processing_admin_communication_work_order_path(resource), method: :put, data: { confirm: "确定要开始处理此工单吗?" }
  end
  action_item :mark_needs_communication, only: :show, if: proc { resource.pending? } do
    link_to "标记需沟通", mark_needs_communication_admin_communication_work_order_path(resource), method: :put, data: { confirm: "确定要标记为需要沟通吗?" }
  end
  action_item :approve, only: :show, if: proc { resource.processing? || resource.needs_communication? } do
    link_to "沟通后通过", approve_admin_communication_work_order_path(resource)
  end
  action_item :reject, only: :show, if: proc { resource.processing? || resource.needs_communication? } do
    link_to "沟通后拒绝", reject_admin_communication_work_order_path(resource)
  end
  action_item :add_communication_record, only: :show do
    link_to "添加沟通记录", new_communication_record_admin_communication_work_order_path(resource)
  end

  # Member Actions
  member_action :start_processing, method: :put do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    if service.start_processing # Potentially pass params
      redirect_to admin_communication_work_order_path(resource), notice: "工单已开始处理"
    else
      redirect_to admin_communication_work_order_path(resource), alert: "操作失败: #{resource.errors.full_messages.join(', ')}"
    end
  end

  member_action :mark_needs_communication, method: :put do
     service = CommunicationWorkOrderService.new(resource, current_admin_user)
    if service.mark_needs_communication # Potentially pass params
      redirect_to admin_communication_work_order_path(resource), notice: "工单已标记为需要沟通"
    else
      redirect_to admin_communication_work_order_path(resource), alert: "操作失败: #{resource.errors.full_messages.join(', ')}"
    end
  end

  member_action :approve, method: :get do
    @communication_work_order = resource
    render :approve # Renders app/views/admin/communication_work_orders/approve.html.erb
  end

  member_action :do_approve, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    permitted_params = params.require(:communication_work_order).permit(:resolution_summary, :problem_type, :problem_description, :remark, :processing_opinion)
    if service.approve(permitted_params)
      redirect_to admin_communication_work_order_path(resource), notice: "工单已沟通通过"
    else
      @communication_work_order = resource
      flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
      render :approve
    end
  end

  member_action :reject, method: :get do
    @communication_work_order = resource
    render :reject # Renders app/views/admin/communication_work_orders/reject.html.erb
  end

  member_action :do_reject, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    permitted_params = params.require(:communication_work_order).permit(:resolution_summary, :problem_type, :problem_description, :remark, :processing_opinion)
    if service.reject(permitted_params)
      redirect_to admin_communication_work_order_path(resource), notice: "工单已沟通拒绝"
    else
      @communication_work_order = resource
      flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
      render :reject
    end
  end

  # Communication Record Actions
  member_action :new_communication_record, method: :get do
     @communication_work_order = resource
     @communication_record = resource.communication_records.build
     render :new_communication_record # Renders app/views/admin/communication_work_orders/new_communication_record.html.erb
  end

  member_action :create_communication_record, method: :post do
    service = CommunicationWorkOrderService.new(resource, current_admin_user)
    record = service.add_communication_record(params.require(:communication_record).permit(:content, :communicator_role, :communicator_name, :communication_method))
    if record.persisted?
      redirect_to admin_communication_work_order_path(resource), notice: "沟通记录已添加"
    else
      @communication_work_order = resource
      @communication_record = record
      flash.now[:alert] = "添加沟通记录失败: #{record.errors.full_messages.join(', ')}"
      render :new_communication_record
    end
  end

   # Fee Detail Verification Actions
   member_action :verify_fee_detail, method: :get do
      @work_order = resource
      @fee_detail = resource.fee_details.find(params[:fee_detail_id])
      render 'admin/shared/verify_fee_detail'
   end

   member_action :do_verify_fee_detail, method: :post do
     service = CommunicationWorkOrderService.new(resource, current_admin_user)
     if service.update_fee_detail_verification(params[:fee_detail_id], params[:verification_status], params[:comment])
        redirect_to admin_communication_work_order_path(resource), notice: "费用明细 ##{params[:fee_detail_id]} 状态已更新"
     else
        @work_order = resource
        @fee_detail = resource.fee_details.find(params[:fee_detail_id])
        flash.now[:alert] = "费用明细 ##{params[:fee_detail_id]} 更新失败: #{@fee_detail.errors.full_messages.join(', ')}"
        render 'admin/shared/verify_fee_detail'
     end
   end

  # Index Page
  index do
    selectable_column
    id_column
    column :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
    column :audit_work_order do |wo| link_to wo.audit_work_order_id, admin_audit_work_order_path(wo.audit_work_order) if wo.audit_work_order_id end
    column :status do |wo| status_tag wo.status end
    column :initiator_role
    column :creator
    column :created_at
    actions
  end

  # Show Page
  show title: proc{|wo| "沟通工单 ##{wo.id}" } do
     tabs do
       tab "基本信息" do
         attributes_table do
           row :id
           row :reimbursement do |wo| link_to wo.reimbursement.invoice_number, admin_reimbursement_path(wo.reimbursement) end
           row :audit_work_order do |wo| link_to wo.audit_work_order_id, admin_audit_work_order_path(wo.audit_work_order) if wo.audit_work_order_id end
           row :type
           row :status do |wo| status_tag wo.status end
           row :communication_method
           row :initiator_role
           row :resolution_summary
           # Show Shared Req 6/7 fields
           row :problem_type
           row :problem_description
           row :remark
           row :processing_opinion
           row :creator
           row :created_at
           row :updated_at
         end
       end

       tab "沟通记录 (#{resource.communication_records.count})" do
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
          div class: "action_items" do
             span class: "action_item" do
               link_to "添加沟通记录", new_communication_record_admin_communication_work_order_path(resource), class: "button"
             end
          end
       end

       tab "费用明细 (#{resource.fee_details.count})" do
          panel "费用明细信息" do
            table_for resource.fee_detail_selections.includes(:fee_detail) do |selection|
               column "费用明细ID", :fee_detail_id do |sel| link_to sel.fee_detail_id, admin_fee_detail_path(sel.fee_detail) end
               column "费用类型", :fee_type do |sel| sel.fee_detail.fee_type end
               column "金额", :amount do |sel| number_to_currency(sel.fee_detail.amount, unit: "¥") end
               column "全局状态", :global_status do |sel| status_tag sel.fee_detail.verification_status end
               column "工单内状态", :verification_status do |sel| status_tag sel.verification_status end
               column "验证意见", :verification_comment
               column "操作" do |sel|
                 link_to("更新验证状态", verify_fee_detail_admin_communication_work_order_path(resource, fee_detail_id: sel.fee_detail_id))
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
              column :changer do |change| change.changer&.email end
            end
          end
       end
     end
     active_admin_comments
  end

  # Form - Use partial
  form partial: 'form'

end
```

### 2.5 其他资源 (FeeDetail, OperationHistory, etc.)

*   Update `FeeDetail` resource.
*   Add `OperationHistory` resource.

```ruby
# app/admin/fee_details.rb
ActiveAdmin.register FeeDetail do
  permit_params :document_number, :fee_type, :amount, :currency, :fee_date, :payment_method, :verification_status

  menu label: "费用明细", parent: "基础数据"
  config.sort_order = 'created_at_desc'

  filter :document_number_cont, label: "报销单号" # Use _cont for string contains
  filter :fee_type
  filter :verification_status, as: :select, collection: FeeDetail::VERIFICATION_STATUSES
  filter :fee_date
  filter :payment_method

  index do
    selectable_column
    id_column
    column :document_number do |fd|
        link_to fd.document_number, admin_reimbursement_path(fd.reimbursement) if fd.reimbursement
    end
    column :fee_type
    column :amount do |fd| number_to_currency(fd.amount, unit: fd.currency || "¥") end
    column :fee_date
    column :verification_status do |fd| status_tag fd.verification_status end
    column :payment_method
    column :created_at
    actions
  end

  show title: proc{|fd| "费用明细 ##{fd.id}" } do
     attributes_table do
        row :id
        row :reimbursement do |fd| link_to fd.document_number, admin_reimbursement_path(fd.reimbursement) if fd.reimbursement end
        row :fee_type
        row :amount do |fd| number_to_currency(fd.amount, unit: fd.currency || "¥") end
        row :currency
        row :fee_date
        row :verification_status do |fd| status_tag fd.verification_status end
        row :payment_method
        row :created_at
        row :updated_at
     end

     panel "关联工单" do
        table_for resource.fee_detail_selections.includes(:work_order) do
            column "工单ID" do |sel|
                link_to sel.work_order_id, polymorphic_path([:admin, sel.work_order]) if sel.work_order
            end
            column "工单类型", :work_order_type
            column "工单状态" do |sel| status_tag sel.work_order.status if sel.work_order end
            column "验证状态 (工单内)", :verification_status do |sel| status_tag sel.verification_status end
            column "验证意见", :verification_comment
        end
     end
     active_admin_comments
  end

  form do |f|
     f.inputs "费用明细信息" do
        # Use string input for document_number if not using standard FK select
        f.input :document_number, label: "报销单号"
        # Or use select if Reimbursement PK is ID
        # f.input :reimbursement_id, as: :select, collection: Reimbursement.all.map { |r| [r.invoice_number, r.id] }
        f.input :fee_type
        f.input :amount
        f.input :currency
        f.input :fee_date, as: :datepicker
        f.input :payment_method
        f.input :verification_status, as: :select, collection: FeeDetail::VERIFICATION_STATUSES, include_blank: false
     end
     f.actions
  end

end

# app/admin/operation_histories.rb
ActiveAdmin.register OperationHistory do
   permit_params :document_number, :operation_type, :operation_time, :operator, :notes

   menu label: "操作历史", parent: "基础数据"
   config.sort_order = 'operation_time_desc'

   filter :document_number_cont, label: "报销单号"
   filter :operation_type
   filter :operator
   filter :operation_time

   index do
     id_column
     column :document_number do |h|
        link_to h.document_number, admin_reimbursement_path(h.reimbursement) if h.reimbursement
     end
     column :operation_type
     column :operator
     column :operation_time
     column :notes
     actions defaults: true do |history|
        # Add custom actions if needed
     end
   end

   show title: proc{|h| "操作历史 ##{h.id}" } do
      attributes_table do
         row :id
         row :reimbursement do |h| link_to h.document_number, admin_reimbursement_path(h.reimbursement) if h.reimbursement end
         row :operation_type
         row :operator
         row :operation_time
         row :notes
         row :created_at
         row :updated_at
      end
      active_admin_comments
   end

   form do |f|
      f.inputs "操作历史信息" do
         f.input :document_number, label: "报销单号"
         f.input :operation_type
         f.input :operator
         f.input :operation_time, as: :datepicker
         f.input :notes, as: :text
      end
      f.actions
   end
end
```

## 3. 自定义视图

*   **Import Views**: (`new_import.html.erb`) - Ensure view exists at `app/views/admin/reimbursements/new_import.html.erb`.
*   **State Change Views**: (`approve.html.erb`, `reject.html.erb`, `new_communication_record.html.erb`, etc.) - Ensure forms include inputs for shared Req 6/7 fields (`problem_type`, etc.) if they are meant to be editable during these actions. Use `polymorphic_path` or specific paths as appropriate for form submissions. Ensure views exist at expected paths (e.g., `app/views/admin/audit_work_orders/approve.html.erb`).
*   **Fee Detail Verification View**: (`admin/shared/verify_fee_detail.html.erb`) - Ensure this uses `polymorphic_path` for submission and exists at `app/views/admin/shared/verify_fee_detail.html.erb`.
*   **Work Order Form Partial**: (`_form.html.erb`) - Create shared partials (e.g., `app/views/admin/audit_work_orders/_form.html.erb`, `app/views/admin/communication_work_orders/_form.html.erb`) including inputs for all relevant fields (common, shared, specific).

```erb
<!-- Example: app/views/admin/audit_work_orders/_form.html.erb -->
<%= semantic_form_for [:admin, @audit_work_order] do |f| %>
  <%= f.inputs "基本信息" do %>
    <% if f.object.new_record? && params[:reimbursement_id] %>
      <%= f.input :reimbursement_id, as: :hidden, input_html: { value: params[:reimbursement_id] } %>
      <li class="string input optional">
          <label class="label">报销单</label>
          <%= link_to f.object.reimbursement&.invoice_number, admin_reimbursement_path(f.object.reimbursement) %>
      </li>
    <% else %>
      <%= f.input :reimbursement_id, as: :select, collection: Reimbursement.all.map { |r| [r.invoice_number, r.id] }, input_html: { disabled: !f.object.new_record? } %>
    <% end %>
    <%= f.input :status, as: :select, collection: AuditWorkOrder.state_machines[:status].states.map(&:value), include_blank: false %>
    <%= f.input :problem_type, as: :select, collection: ["问题类型A", "问题类型B", "其他"], include_blank: '无' %>
    <%= f.input :problem_description, as: :select, collection: ["问题描述1", "问题描述2", "其他"], include_blank: '无' %>
    <%= f.input :remark, as: :text, input_html: { rows: 3 } %>
    <%= f.input :processing_opinion, as: :select, collection: ["处理意见X", "处理意见Y", "其他"], include_blank: '无' %>
    <%= f.input :audit_comment, as: :text, input_html: { rows: 3 } %>
    <%= f.input :vat_verified %>
  <% end %>
  <%= f.inputs "选择费用明细" do %>
     <%= f.input :fee_detail_ids, as: :check_boxes, collection: f.object.reimbursement&.fee_details&.map { |fd| ["##{fd.id} #{fd.fee_type} (#{number_to_currency(fd.amount)}) - #{fd.verification_status}", fd.id] } || [], label: false %>
  <% end %>
  <%= f.actions %>
<% end %>

<!-- Example: app/views/admin/communication_work_orders/_form.html.erb -->
<%= semantic_form_for [:admin, @communication_work_order] do |f| %>
  <%= f.inputs "基本信息" do %>
    <%# Similar logic for reimbursement_id %>
     <% if f.object.new_record? && params[:reimbursement_id] %>
       <%= f.input :reimbursement_id, as: :hidden, input_html: { value: params[:reimbursement_id] } %>
       <li class="string input optional"> <label class="label">报销单</label> <%= link_to f.object.reimbursement&.invoice_number, admin_reimbursement_path(f.object.reimbursement) %> </li>
     <% else %>
       <%= f.input :reimbursement_id, as: :select, collection: Reimbursement.all.map { |r| [r.invoice_number, r.id] }, input_html: { disabled: !f.object.new_record? } %>
     <% end %>
    <%# Link to parent Audit Work Order is crucial %>
    <%= f.input :audit_work_order_id, as: :select, collection: AuditWorkOrder.where(reimbursement_id: f.object.reimbursement_id).map { |aw| ["审核工单 ##{aw.id} (#{aw.status})", aw.id] }, include_blank: false, required: true %>
    <%= f.input :status, as: :select, collection: CommunicationWorkOrder.state_machines[:status].states.map(&:value), include_blank: false %>
    <%= f.input :communication_method, as: :select, collection: ["email", "phone", "system", "other"] %>
    <%= f.input :initiator_role, as: :select, collection: ["auditor", "applicant", "manager", "other"] %>
    <%= f.input :problem_type, as: :select, collection: ["问题类型A", "问题类型B", "其他"], include_blank: '无' %>
    <%= f.input :problem_description, as: :select, collection: ["问题描述1", "问题描述2", "其他"], include_blank: '无' %>
    <%= f.input :remark, as: :text, input_html: { rows: 3 } %>
    <%= f.input :processing_opinion, as: :select, collection: ["处理意见X", "处理意见Y", "其他"], include_blank: '无' %>
    <%= f.input :resolution_summary, as: :text, input_html: { rows: 3 } %>
  <% end %>
   <%= f.inputs "选择费用明细" do %>
     <%= f.input :fee_detail_ids, as: :check_boxes, collection: f.object.reimbursement&.fee_details&.map { |fd| ["##{fd.id} #{fd.fee_type} (#{number_to_currency(fd.amount)}) - #{fd.verification_status}", fd.id] } || [], label: false %>
  <% end %>
  <%= f.actions %>
<% end %>

<!-- Example: app/views/admin/shared/verify_fee_detail.html.erb -->
<%# Assume @work_order and @fee_detail are set by the controller action %>
<% work_order_type = @work_order.class.name.underscore %>
<% provide :title, "验证费用明细 ##{@fee_detail.id} - #{work_order_type.titleize} ##{@work_order.id}" %>
<h2>验证费用明细 #<%= @fee_detail.id %> - <%= work_order_type.titleize %> #<%= @work_order.id %></h2>

<%# Use polymorphic_path for the form URL %>
<%= semantic_form_for [:admin, @work_order], url: polymorphic_path([:do_verify_fee_detail, :admin, @work_order]), method: :post do |f| %>
  <%= hidden_field_tag :fee_detail_id, @fee_detail.id %>
  <%= f.inputs do %>
    <li class="string input optional"> <label class="label">费用类型</label> <%= @fee_detail.fee_type %> </li>
    <li class="string input optional"> <label class="label">金额</label> <%= number_to_currency(@fee_detail.amount, unit: "¥") %> </li>
    <li class="string input optional"> <label class="label">当前全局状态</label> <%= status_tag @fee_detail.verification_status %> </li>
    <% selection = @work_order.fee_detail_selections.find_by(fee_detail_id: @fee_detail.id) %>
    <li class="string input optional"> <label class="label">当前工单内状态</label> <%= status_tag selection&.verification_status %> </li>
    <%# Use verification_status parameter name %>
    <%= label_tag :verification_status, "设置验证状态 *" %>
    <%= select_tag :verification_status, options_for_select(FeeDetail::VERIFICATION_STATUSES.map { |s| [s.titleize, s] }, selection&.verification_status), required: true %>
    <%# Use comment parameter name %>
    <%= label_tag :comment, "验证意见" %>
    <%= text_area_tag :comment, selection&.verification_comment, rows: 3 %>
  <% end %>
  <%= f.actions do %>
    <%= f.action :submit, label: "提交", button_html: { class: "button" } %>
    <%= f.action :cancel, label: "取消", wrapper_html: { class: 'cancel' }, button_html: { type: 'link', href: polymorphic_path([:admin, @work_order]) } %>
  <% end %>
<% end %>

<!-- Example: app/views/admin/audit_work_orders/approve.html.erb -->
<% @page_title = "审核通过 - 审核工单 ##{@audit_work_order.id}" %>
<%= semantic_form_for [:admin, @audit_work_order], url: do_approve_admin_audit_work_order_path(@audit_work_order), method: :post do |f| %>
  <%= f.inputs "审核通过意见" do %>
    <li class="string input optional"> <label class="label">报销单</label> <%= link_to @audit_work_order.reimbursement.invoice_number, admin_reimbursement_path(@audit_work_order.reimbursement) %> </li>
    <%# Include shared fields if editable here %>
    <%= f.input :audit_comment, as: :text, label: "审核意见", input_html: { rows: 5 } %>
  <% end %>
  <%= f.actions do %>
    <%= f.action :submit, label: "确认通过" %>
    <%= f.action :cancel, label: "取消", wrapper_html: { class: 'cancel' }, button_html: { type: 'link', href: admin_audit_work_order_path(@audit_work_order) } %>
  <% end %>
<% end %>

<!-- Example: app/views/admin/communication_work_orders/new_communication_record.html.erb -->
<% @page_title = "添加沟通记录 - 沟通工单 ##{@communication_work_order.id}" %>
<%= semantic_form_for [:admin, @communication_work_order, @communication_record || CommunicationRecord.new], url: create_communication_record_admin_communication_work_order_path(@communication_work_order), method: :post do |f| %>
  <%= f.inputs "沟通记录" do %>
    <%= f.input :content, as: :text, label: "沟通内容", input_html: { rows: 5, required: true } %>
    <%= f.input :communicator_role, as: :select, collection: [["审核人", "auditor"], ["申请人", "applicant"], ["管理员", "admin"], ["其他", "other"]], label: "沟通角色", required: true %>
    <%= f.input :communicator_name, as: :string, label: "沟通人姓名", input_html: { value: current_admin_user.email } %>
    <%= f.input :communication_method, as: :select, collection: [["系统", "system"], ["邮件", "email"], ["电话", "phone"], ["其他", "other"]], label: "沟通方式", required: true %>
  <% end %>
  <%= f.actions do %>
    <%= f.action :submit, label: "添加记录" %>
    <%= f.action :cancel, label: "取消", wrapper_html: { class: 'cancel' }, button_html: { type: 'link', href: admin_communication_work_order_path(@communication_work_order) } %>
  <% end %>
<% end %>

```

## 4. 注意事项

*   **Shared Form Fields**: The shared Req 6/7 fields (`problem_type`, etc.) are now included in the `WorkOrder` table and relevant ActiveAdmin resources/forms. Decide if they are mandatory and where they should be editable (creation, state transitions, general edit). Adjust `permit_params` and form views accordingly.
*   **Form Partials**: Using partials (`form partial: 'form'`) is recommended for the `AuditWorkOrder` and `CommunicationWorkOrder` forms due to the shared fields. Ensure these partials exist (e.g., `app/views/admin/audit_work_orders/_form.html.erb`).
*   **Service Layer**: Services now accept and assign these shared fields. Ensure controllers pass permitted parameters correctly.
*   **View Paths**: Ensure custom views for actions like `approve`, `reject`, `new_communication_record`, `verify_fee_detail` exist at the expected locations (e.g., `app/views/admin/audit_work_orders/approve.html.erb`).