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

  collection_action :new_import, method: :get do
    render "admin/reimbursements/new_import"
  end

  collection_action :import, method: :post do
    service = reimbursement_import_service(params[:file])
    result = service.import

    if result[:success]
      redirect_to admin_reimbursements_path, notice: "导入成功: #{result[:created]} 创建, #{result[:updated]} 更新, #{result[:errors]} 错误."
    else
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
              links << link_to("查看", admin_fee_detail_path(fee_detail))
              links.join(" | ").html_safe
            end
          end
        end
      end

      tab "操作历史" do
        panel "操作历史信息" do
          table_for resource.operation_histories do
            column :id
            column :operation_type
            column :operation_time
            column :operator
            column :created_at
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