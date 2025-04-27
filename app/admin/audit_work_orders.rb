ActiveAdmin.register AuditWorkOrder do
  # 权限控制
  permit_params :reimbursement_id, :express_receipt_work_order_id, :status, :audit_result,
                :audit_comment, :audit_date, :vat_verified, :created_by

  # 菜单设置
  menu priority: 3, label: "审核工单"

  # 过滤器
  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :status, as: :select, collection: ['pending', 'processing', 'auditing', 'approved', 'rejected', 'needs_communication', 'completed']
  filter :audit_result, as: :select, collection: ["approved", "rejected"]
  filter :audit_date
  filter :created_at

  # 自定义页面

  member_action :approve, method: :post do
    service = audit_work_order_service(resource)

    if service.approve(params[:audit_comment])
      redirect_to admin_audit_work_order_path(resource), notice: "审核已通过"
    else
      redirect_to admin_audit_work_order_path(resource), alert: "操作失败: #{resource.errors.full_messages.join(', ')}"
    end
  end

  member_action :reject, method: :post do
    service = audit_work_order_service(resource)

    if service.reject(params[:audit_comment])
      redirect_to admin_audit_work_order_path(resource), notice: "审核已拒绝"
    else
      redirect_to admin_audit_work_order_path(resource), alert: "操作失败: #{resource.errors.full_messages.join(', ')}"
    end
  end

  member_action :need_communication, method: :post do
    service = audit_work_order_service(resource)

    if service.need_communication(params[:audit_comment])
      redirect_to admin_audit_work_order_path(resource), notice: "已标记为需要沟通"
    else
      redirect_to admin_audit_work_order_path(resource), alert: "操作失败: #{resource.errors.full_messages.join(', ')}"
    end
  end

  # ... other existing member actions ...

  # 表单
  form do |f|
    f.inputs "审核工单信息" do
      f.input :reimbursement_id, as: :select, collection: Reimbursement.all.map { |r| [r.invoice_number, r.id] }
      f.input :express_receipt_work_order_id, as: :select, collection: ExpressReceiptWorkOrder.all.map { |w| [w.id, w.id] }
      f.input :status, as: :select, collection: ['pending', 'processing', 'auditing', 'approved', 'rejected', 'needs_communication', 'completed']
      f.input :audit_result, as: :select, collection: ["approved", "rejected"]
      f.input :audit_comment
      f.input :audit_date, as: :datepicker
      f.input :vat_verified
      f.input :created_by, input_html: { value: current_admin_user.id }, as: :hidden
    end
    f.actions
  end
end