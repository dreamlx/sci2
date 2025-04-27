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

  action_item :export_status_changes, only: :show do
    link_to "导出状态变更", export_status_changes_admin_express_receipt_work_order_path(resource, format: :csv)
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

  member_action :export_status_changes, method: :get do
    @status_changes = resource.work_order_status_changes.order(changed_at: :desc)
    respond_to do |format|
      format.csv do
        headers['Content-Disposition'] = "attachment; filename=\"status_changes_#{resource.id}.csv\""
      end
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
      div class: "status-changes-header" do
        span "状态变更历史"
        span do
          link_to "导出CSV", export_status_changes_admin_express_receipt_work_order_path(resource, format: :csv), class: "export-link"
        end
      end
      
      table_for resource.work_order_status_changes.order(changed_at: :desc) do
        column :from_status
        column :to_status
        column :changed_at
        column :changed_by do |change|
          AdminUser.find_by(id: change.changed_by)&.email || "系统"
        end
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
        if resource.status == "completed"
          para do
            link_to "创建审核工单", new_admin_audit_work_order_path(audit_work_order: { 
              reimbursement_id: resource.reimbursement_id,
              express_receipt_work_order_id: resource.id,
              status: "pending",
              created_by: current_admin_user.id
            })
          end
        end
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