ActiveAdmin.register FeeDetail do
  # 权限控制
  permit_params :document_number, :fee_type, :amount, :currency, :fee_date, 
                :payment_method, :verification_status

  # 菜单设置
  menu priority: 5, label: "费用明细"

  # 过滤器
  filter :document_number
  filter :fee_type
  filter :amount
  filter :fee_date
  filter :verification_status, as: :select, collection: FeeDetail::VERIFICATION_STATUSES
  filter :created_at

  # 批量操作
  batch_action :mark_as_verified do |ids|
    batch_action_collection.find(ids).each do |fee_detail|
      fee_detail.mark_as_verified
    end
    redirect_to collection_path, notice: "已将选中的费用明细标记为已验证"
  end

  batch_action :mark_as_rejected do |ids|
    batch_action_collection.find(ids).each do |fee_detail|
      fee_detail.mark_as_rejected
    end
    redirect_to collection_path, notice: "已将选中的费用明细标记为已拒绝"
  end

  batch_action :mark_as_problematic do |ids|
    batch_action_collection.find(ids).each do |fee_detail|
      fee_detail.mark_as_problematic
    end
    redirect_to collection_path, notice: "已将选中的费用明细标记为有问题"
  end

  # 自定义操作
  action_item :mark_as_verified, only: :show, if: proc { !resource.verified? } do
    link_to "标记为已验证", mark_as_verified_admin_fee_detail_path(resource), method: :put
  end

  action_item :mark_as_rejected, only: :show, if: proc { !resource.rejected? } do
    link_to "标记为已拒绝", mark_as_rejected_admin_fee_detail_path(resource), method: :put
  end

  action_item :mark_as_problematic, only: :show, if: proc { !resource.problematic? } do
    link_to "标记为有问题", mark_as_problematic_admin_fee_detail_path(resource), method: :put
  end

  action_item :mark_as_pending, only: :show, if: proc { !resource.pending? } do
    link_to "标记为待验证", mark_as_pending_admin_fee_detail_path(resource), method: :put
  end

  # 自定义页面
  member_action :mark_as_verified, method: :put do
    resource.mark_as_verified
    redirect_to admin_fee_detail_path(resource), notice: "费用明细已标记为已验证"
  end

  member_action :mark_as_rejected, method: :put do
    resource.mark_as_rejected
    redirect_to admin_fee_detail_path(resource), notice: "费用明细已标记为已拒绝"
  end

  member_action :mark_as_problematic, method: :put do
    resource.mark_as_problematic
    redirect_to admin_fee_detail_path(resource), notice: "费用明细已标记为有问题"
  end

  member_action :mark_as_pending, method: :put do
    resource.mark_as_pending
    redirect_to admin_fee_detail_path(resource), notice: "费用明细已标记为待验证"
  end

  # 列表页
  index do
    selectable_column
    id_column
    column :document_number do |fee_detail|
      if fee_detail.reimbursement.present?
        link_to fee_detail.document_number, admin_reimbursement_path(fee_detail.reimbursement)
      else
        fee_detail.document_number
      end
    end
    column :fee_type
    column :amount do |fee_detail|
      number_to_currency(fee_detail.amount, unit: fee_detail.currency)
    end
    column :fee_date
    column :payment_method
    column :verification_status do |fee_detail|
      status_tag fee_detail.verification_status
    end
    column :created_at
    actions
  end

  # 详情页
  show do
    tabs do
      tab "基本信息" do
        attributes_table do
          row :id
          row :document_number do |fee_detail|
            if fee_detail.reimbursement.present?
              link_to fee_detail.document_number, admin_reimbursement_path(fee_detail.reimbursement)
            else
              fee_detail.document_number
            end
          end
          row :fee_type
          row :amount do |fee_detail|
            number_to_currency(fee_detail.amount, unit: fee_detail.currency)
          end
          row :currency
          row :fee_date
          row :payment_method
          row :verification_status do |fee_detail|
            status_tag fee_detail.verification_status
          end
          row :created_at
          row :updated_at
        end
      end

      tab "审核工单" do
        panel "关联的审核工单" do
          table_for resource.audit_work_orders do
            column :id do |work_order|
              link_to work_order.id, admin_audit_work_order_path(work_order)
            end
            column :status do |work_order|
              status_tag work_order.status
            end
            column :audit_result do |work_order|
              status_tag work_order.audit_result if work_order.audit_result.present?
            end
            column :created_at
          end
        end
      end

      tab "沟通工单" do
        panel "关联的沟通工单" do
          table_for resource.communication_work_orders do
            column :id do |work_order|
              link_to work_order.id, admin_communication_work_order_path(work_order)
            end
            column :status do |work_order|
              status_tag work_order.status
            end
            column :resolution_summary
            column :created_at
          end
        end
      end

      tab "验证历史" do
        panel "费用明细选择记录" do
          table_for resource.fee_detail_selections.includes(:audit_work_order, :communication_work_order).order(created_at: :desc) do
            column "工单类型" do |selection|
              if selection.audit_work_order.present?
                "审核工单"
              elsif selection.communication_work_order.present?
                "沟通工单"
              else
                "未知"
              end
            end
            column "工单ID" do |selection|
              if selection.audit_work_order.present?
                link_to selection.audit_work_order.id, admin_audit_work_order_path(selection.audit_work_order)
              elsif selection.communication_work_order.present?
                link_to selection.communication_work_order.id, admin_communication_work_order_path(selection.communication_work_order)
              end
            end
            column :verification_status do |selection|
              status_tag selection.verification_status
            end
            column :verification_comment
            column :verified_by do |selection|
              AdminUser.find_by(id: selection.verified_by)&.email
            end
            column :verified_at
            column :created_at
          end
        end
      end
    end
  end

  # 表单
  form do |f|
    f.inputs "费用明细信息" do
      f.input :document_number
      f.input :fee_type
      f.input :amount
      f.input :currency
      f.input :fee_date, as: :datepicker
      f.input :payment_method
      f.input :verification_status, as: :select, collection: FeeDetail::VERIFICATION_STATUSES
    end
    f.actions
  end
end