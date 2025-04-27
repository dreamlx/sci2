ActiveAdmin.register CommunicationWorkOrder do
  # 权限控制
  permit_params :reimbursement_id, :audit_work_order_id, :status, :communication_method,
                :initiator_role, :resolution_summary, :created_by

  # 菜单设置
  menu priority: 4, label: "沟通工单"

  # 过滤器
  filter :reimbursement_invoice_number, as: :string, label: '报销单号'
  filter :audit_work_order_id
  filter :status, as: :select, collection: ['open', 'in_progress', 'resolved', 'unresolved', 'closed']
  filter :communication_method
  filter :initiator_role
  filter :created_at

  # 自定义操作
  action_item :start_communication, only: :show, if: proc { resource.status == 'open' } do
    link_to "开始沟通", start_communication_admin_communication_work_order_path(resource), method: :put
  end

  action_item :add_communication_record, only: :show, if: proc { resource.status == 'in_progress' } do
    link_to "添加沟通记录", new_communication_record_admin_communication_work_order_path(resource)
  end

  action_item :resolve, only: :show, if: proc { resource.status == 'in_progress' } do
    link_to "标记已解决", resolve_admin_communication_work_order_path(resource)
  end

  action_item :mark_unresolved, only: :show, if: proc { resource.status == 'in_progress' } do
    link_to "标记未解决", mark_unresolved_admin_communication_work_order_path(resource)
  end

  action_item :close, only: :show, if: proc { ['resolved', 'unresolved'].include?(resource.status) } do
    link_to "关闭", close_admin_communication_work_order_path(resource), method: :put
  end

  # 自定义页面
  member_action :start_communication, method: :put do
    begin
      resource.start_communication
      redirect_to admin_communication_work_order_path(resource), notice: "工单已开始沟通"
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_communication_work_order_path(resource), alert: "状态转换失败: #{e.message}"
    end
  end

  member_action :new_communication_record, method: :get do
    render :new_communication_record
  end

  member_action :create_communication_record, method: :post do
    record = resource.add_communication_record(params.require(:communication_record).permit(:content, :communicator_role, :communicator_name, :communication_method))
    if record.persisted?
      redirect_to admin_communication_work_order_path(resource), notice: "沟通记录已添加"
    else
      render :new_communication_record, alert: "添加沟通记录失败: #{record.errors.full_messages.join(', ')}"
    end
  end

  member_action :resolve, method: :get do
    render :resolve
  end

  member_action :do_resolve, method: :post do
    begin
      resource.update(resolution_summary: params[:resolution_summary])
      resource.resolve
      redirect_to admin_communication_work_order_path(resource), notice: "工单已标记为已解决"
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_communication_work_order_path(resource), alert: "状态转换失败: #{e.message}"
    end
  end

  member_action :mark_unresolved, method: :get do
    render :mark_unresolved
  end

  member_action :do_mark_unresolved, method: :post do
    begin
      resource.update(resolution_summary: params[:resolution_summary])
      resource.mark_unresolved
      redirect_to admin_communication_work_order_path(resource), notice: "工单已标记为未解决"
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_communication_work_order_path(resource), alert: "状态转换失败: #{e.message}"
    end
  end

  member_action :close, method: :put do
    begin
      resource.close
      redirect_to admin_communication_work_order_path(resource), notice: "工单已关闭"
    rescue StateMachines::InvalidTransition => e
      redirect_to admin_communication_work_order_path(resource), alert: "状态转换失败: #{e.message}"
    end
  end

  member_action :resolve_fee_detail_issue, method: :get do
    @fee_detail = FeeDetail.find(params[:fee_detail_id])
    render :resolve_fee_detail_issue
  end

  member_action :do_resolve_fee_detail_issue, method: :post do
    fee_detail = FeeDetail.find(params[:fee_detail_id])
    if resource.resolve_fee_detail_issue(fee_detail, params[:resolution])
      redirect_to admin_communication_work_order_path(resource), notice: "费用明细 ##{params[:fee_detail_id]} 问题备注已更新"
    else
      @fee_detail = fee_detail
      render :resolve_fee_detail_issue, alert: "更新费用明细备注失败"
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

      tab "关联费用明细" do
        panel "费用明细信息" do
          table_for resource.fee_detail_selections.includes(:fee_detail) do
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
              links << link_to("添加/更新解决备注", resolve_fee_detail_issue_admin_communication_work_order_path(resource, fee_detail_id: sel.fee_detail_id))
              links.join(" | ").html_safe
            end
          end
        end
      end

      tab "状态变更历史" do
        panel "状态变更历史" do
          table_for resource.status_changes do
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
      f.input :status, as: :select, collection: ['open', 'in_progress', 'resolved', 'unresolved', 'closed']
      f.input :communication_method, as: :select, collection: ["email", "phone", "system", "other"]
      f.input :initiator_role, as: :select, collection: ["auditor", "applicant", "manager", "other"]
      f.input :resolution_summary
      f.input :created_by, input_html: { value: current_admin_user.id }, as: :hidden
    end
    f.actions
  end
end