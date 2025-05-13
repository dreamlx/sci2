ActiveAdmin.register Reimbursement do
  permit_params :invoice_number, :document_name, :applicant, :applicant_id, :company, :department,
                :amount, :receipt_status, :status, :receipt_date, :submission_date,
                :is_electronic, :external_status, :approval_date, :approver_name

  menu priority: 2, label: "报销单管理"

  # 过滤器
  filter :invoice_number
  filter :applicant
  filter :status, label: "内部状态", as: :select, collection: Reimbursement.state_machines[:status].states.map(&:value)
  filter :external_status, label: "外部状态"
  filter :receipt_status, as: :select, collection: ["pending", "received"]
  filter :is_electronic, as: :boolean
  filter :created_at
  filter :approval_date

  # 列表页范围过滤器
  scope :all, default: true
  scope :pending
  scope :processing
  scope :approved
  scope :rejected
  scope :closed

  # 批量操作
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

  # 操作按钮
  action_item :import, only: :index do
    link_to "导入报销单", new_import_admin_reimbursements_path
  end
  
  action_item :import_operation_histories, only: :index do
    link_to "导入操作历史", operation_histories_admin_imports_path
  end
  
  # 移除默认的编辑和删除按钮
  config.action_items.delete_if { |item| item.name == :edit || item.name == :destroy }
  
  # 添加自定义按钮，按照指定顺序排列
  action_item :new_audit_work_order, only: :show, priority: 0 do
    link_to "新建审核工单", new_admin_audit_work_order_path(reimbursement_id: resource.id)
  end
  
  action_item :new_communication_work_order, only: :show, priority: 1 do
    link_to "新建沟通工单", new_admin_communication_work_order_path(reimbursement_id: resource.id)
  end
  
  action_item :edit_reimbursement, only: :show, priority: 2 do
    link_to "编辑报销单", edit_admin_reimbursement_path(resource)
  end
  
  action_item :delete_reimbursement, only: :show, priority: 3 do
    link_to "删除报销单", admin_reimbursement_path(resource),
            method: :delete,
            data: { confirm: "确定要删除此报销单吗？此操作不可逆。" }
  end

  # 导入操作
  collection_action :new_import, method: :get do
    render "admin/shared/import_form", locals: {
      title: "导入报销单",
      import_path: import_admin_reimbursements_path,
      cancel_path: admin_reimbursements_path,
      instructions: [
        "请上传CSV格式文件",
        "文件必须包含以下列：发票号码,文档名称,申请人,申请人ID,公司,部门,金额,收单状态,状态,收单日期,提交日期,是否电子发票,外部状态,审批日期,审批人",
        "如果报销单已存在（根据发票号码判断），将更新现有记录",
        "如果报销单不存在，将创建新记录"
      ]
    }
  end

  collection_action :import, method: :post do
    # 确保文件参数存在
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

  # 列表页
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

  # 详情页状态操作按钮
  action_item :start_processing, only: :show, if: proc{resource.pending?} do
    link_to "开始处理", start_processing_admin_reimbursement_path(resource), method: :put, data: { confirm: "确定要开始处理此报销单吗?" }
  end

  member_action :start_processing, method: :put do
    begin
      resource.start_processing!
      redirect_to admin_reimbursement_path(resource), notice: "报销单已开始处理"
    rescue => e
      redirect_to admin_reimbursement_path(resource), alert: "操作失败: #{e.message}"
    end
  end

  member_action :close, method: :put do
    begin
      resource.close!
      redirect_to admin_reimbursement_path(resource), notice: "报销单已关闭"
    rescue => e
      redirect_to admin_reimbursement_path(resource), alert: "操作失败: #{e.message}"
    end
  end

  # 详情页
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

        panel "费用明细信息" do
          table_for resource.fee_details.order(created_at: :desc) do
            column(:id) { |fd| link_to fd.id, admin_fee_detail_path(fd) }
            column :fee_type
            column "金额", :amount do |fd| number_to_currency(fd.amount, unit: "¥") end
            column :fee_date
            column "验证状态", :verification_status do |fd| status_tag fd.verification_status end
            column :payment_method
            column "创建时间", :created_at
          end
        end

        # New panel to display total amount again for double check
        div "报销总金额复核" do
          hr 
          attributes_table_for resource do
            row :amount, label: "总金额" do |reimbursement| 
              strong { number_to_currency(reimbursement.amount, unit: "¥") }
            end
          end
        end

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
            column("处理结果", :resolution) { |wo| status_tag wo.resolution if wo.resolution.present? }
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
    end
  end

  # 表单页
  form do |f|
    f.inputs "报销单信息" do
      f.input :invoice_number, input_html: { readonly: !f.object.new_record? }
      f.input :document_name
      f.input :applicant
      f.input :applicant_id
      f.input :company
      f.input :department
      f.input :amount, min: 0.01
      f.input :status, label: "内部状态", as: :select, collection: Reimbursement.state_machines[:status].states.map(&:value), include_blank: false
      f.input :external_status, label: "外部状态", input_html: { readonly: true }
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