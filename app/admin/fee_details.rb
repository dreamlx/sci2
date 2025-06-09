ActiveAdmin.register FeeDetail do
  actions :index, :show
  permit_params :reimbursement_id, :document_number, :fee_type, :amount, :fee_date,
                :verification_status, :notes, :external_fee_id, :month_belonging,
                :first_submission_date, :plan_or_pre_application, :product,
                :flex_field_6, :flex_field_7, :expense_corresponding_plan,
                :expense_associated_application

  menu priority: 3, parent: "数据管理", label: "费用明细"

  filter :document_number, as: :string, label: "报销单号"
  filter :external_fee_id, as: :string, label: "费用ID"
  filter :fee_type
  filter :verification_status, as: :select, collection: ["pending", "problematic", "verified"]
  filter :fee_date
  filter :month_belonging, as: :string, label: "所属月"
  filter :product, as: :string, label: "产品"
  filter :plan_or_pre_application, as: :string, label: "计划/预申请"
  filter :expense_associated_application, as: :string, label: "费用关联申请单"
  filter :created_at
  
  # 添加关联报销单的过滤器
  filter :reimbursement_applicant, as: :string, label: "申请人名称"
  filter :reimbursement_applicant_id, as: :string, label: "申请人工号"
  filter :reimbursement_company, as: :string, label: "申请人公司"
  filter :reimbursement_department, as: :string, label: "申请人部门"


  collection_action :new_import, method: :get do
    render "admin/shared/import_form", locals: {
      title: "导入费用明细",
      import_path: import_admin_fee_details_path,
      cancel_path: admin_fee_details_path,
      instructions: [
        "请上传CSV格式文件",
        "文件必须包含以下列：报销单号,费用id,费用类型,原始金额,费用发生日期",
        "其他有用字段：所属月,首次提交日期,计划/预申请,产品,弹性字段6,弹性字段7,费用对应计划,费用关联申请单,备注",
        "系统会根据报销单号关联到已存在的报销单",
        "如果费用明细已存在（根据费用id判断），将更新现有记录",
        "如果费用明细不存在，将创建新记录"
      ]
    }
  end

  collection_action :import, method: :post do
    unless params[:file].present?
      redirect_to new_import_admin_fee_details_path, alert: "请选择要导入的文件。"
      return
    end

    service = FeeDetailImportService.new(params[:file], current_admin_user)
    result = service.import

    if result[:success]
      notice_message = "导入成功: #{result[:created]} 创建, #{result[:updated]} 更新."
      notice_message += " #{result[:skipped_errors]} 错误." if result[:skipped_errors].to_i > 0
      notice_message += " #{result[:unmatched_count]} 未匹配的报销单." if result[:unmatched_count].to_i > 0
      redirect_to admin_fee_details_path, notice: notice_message
    else
      alert_message = "导入失败: #{result[:error_details] ? result[:error_details].join(', ') : (result[:errors].is_a?(Array) ? result[:errors].join(', ') : result[:errors])}"
      redirect_to new_import_admin_fee_details_path, alert: alert_message
    end
  end
  
  # 添加导出功能
  collection_action :export_csv, method: :get do
    fee_details = FeeDetail.includes(:reimbursement).ransack(params[:q]).result
    
    csv_data = CSV.generate(headers: true, force_quotes: true) do |csv|
      # 添加CSV头部，与导入文件保持一致
      csv << [
        "所属月", "费用类型", "申请人名称", "申请人工号", "申请人公司", "申请人部门",
        "费用发生日期", "原始金额", "单据名称", "报销单单号", "关联申请单号",
        "计划/预申请", "产品", "弹性字段11", "弹性字段6(报销单)", "弹性字段7(报销单)",
        "费用id", "首次提交日期", "费用对应计划", "费用关联申请单"
      ]
      
      # 添加数据行
      fee_details.find_each do |fee_detail|
        reimbursement = fee_detail.reimbursement
        
        csv << [
          fee_detail.month_belonging,
          fee_detail.fee_type,
          reimbursement&.applicant,
          reimbursement&.applicant_id,
          reimbursement&.company,
          reimbursement&.department,
          fee_detail.fee_date,
          fee_detail.amount,
          reimbursement&.document_name,
          fee_detail.document_number,
          reimbursement&.related_application_number,
          fee_detail.plan_or_pre_application,
          fee_detail.product,
          fee_detail.flex_field_11,
          fee_detail.flex_field_6,
          fee_detail.flex_field_7,
          fee_detail.external_fee_id,
          fee_detail.first_submission_date,
          fee_detail.expense_corresponding_plan,
          fee_detail.expense_associated_application
        ]
      end
    end
    
    send_data csv_data,
              type: 'text/csv; charset=utf-8; header=present',
              disposition: "attachment; filename=费用明细_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
  end

  index do
    selectable_column
    id_column
    column :reimbursement do |fee_detail|
      link_to fee_detail.document_number, admin_reimbursement_path(fee_detail.reimbursement) if fee_detail.reimbursement
    end
    column "申请人", sortable: false do |fee_detail|
      fee_detail.reimbursement&.applicant
    end
    column "申请人工号", sortable: false do |fee_detail|
      fee_detail.reimbursement&.applicant_id
    end
    column :fee_type
    column :amount do |fee_detail|
      number_to_currency(fee_detail.amount, unit: "¥")
    end
    column :fee_date
    column :month_belonging
    column :external_fee_id
    column :verification_status do |fee_detail|
      status_tag fee_detail.verification_status
    end
    column :created_at
    actions
    
    # 添加导出按钮到页面顶部
    div class: "action_items" do
      span class: "action_item" do
        link_to "导出CSV", export_csv_admin_fee_details_path(q: params[:q]), class: "button"
      end
    end
  end

  show do
    tabs do
      tab "基本信息" do
        attributes_table do
          row :id
          row :reimbursement do |fee_detail|
            link_to fee_detail.document_number, admin_reimbursement_path(fee_detail.reimbursement) if fee_detail.reimbursement
          end
          row :external_fee_id
          row :fee_type
          row :amount do |fee_detail|
            number_to_currency(fee_detail.amount, unit: "¥") if fee_detail.amount.present?
          end
          row :fee_date
          row :verification_status do |fee_detail|
            status_tag fee_detail.verification_status if fee_detail.verification_status.present?
          end
          row :month_belonging
          row :first_submission_date
          row :plan_or_pre_application
          row :product
          row :flex_field_11
          row :flex_field_6
          row :flex_field_7
          row :expense_corresponding_plan
          row :expense_associated_application
          row :notes
          row :created_at
          row :updated_at
        end
      end
      
      tab "CSV导入数据" do
        panel "完整CSV数据" do
          attributes_table_for resource do
            # FeeDetail fields
            row "费用ID" do |fee_detail|
              fee_detail.external_fee_id
            end
            row "费用类型" do |fee_detail|
              fee_detail.fee_type
            end
            row "原始金额" do |fee_detail|
              number_to_currency(fee_detail.amount, unit: "¥") if fee_detail.amount.present?
            end
            row "费用发生日期" do |fee_detail|
              fee_detail.fee_date
            end
            row "所属月" do |fee_detail|
              fee_detail.month_belonging
            end
            row "首次提交日期" do |fee_detail|
              fee_detail.first_submission_date
            end
            row "计划/预申请" do |fee_detail|
              fee_detail.plan_or_pre_application
            end
            row "产品" do |fee_detail|
              fee_detail.product
            end
            row "弹性字段11" do |fee_detail|
              fee_detail.flex_field_11
            end
            row "弹性字段6(报销单)" do |fee_detail|
              fee_detail.flex_field_6
            end
            row "弹性字段7(报销单)" do |fee_detail|
              fee_detail.flex_field_7
            end
            row "费用对应计划" do |fee_detail|
              fee_detail.expense_corresponding_plan
            end
            row "费用关联申请单" do |fee_detail|
              fee_detail.expense_associated_application
            end
            
            # Reimbursement fields
            if resource.reimbursement.present?
              row "报销单单号" do |fee_detail|
                fee_detail.document_number
              end
              row "单据名称" do |fee_detail|
                fee_detail.reimbursement.document_name
              end
              row "申请人名称" do |fee_detail|
                fee_detail.reimbursement.applicant
              end
              row "申请人工号" do |fee_detail|
                fee_detail.reimbursement.applicant_id
              end
              row "申请人公司" do |fee_detail|
                fee_detail.reimbursement.company
              end
              row "申请人部门" do |fee_detail|
                fee_detail.reimbursement.department
              end
              row "关联申请单号" do |fee_detail|
                fee_detail.reimbursement.related_application_number
              end
            end
          end
        end
      end

      tab "关联工单 (#{resource.work_orders.count})" do
        panel "关联工单信息" do
          if resource.work_orders.any?
            table_for resource.work_orders.includes(:reimbursement) do
              column "工单ID" do |work_order|
                case work_order.type
                when 'AuditWorkOrder'
                  link_to work_order.id, admin_audit_work_order_path(work_order)
                when 'CommunicationWorkOrder'
                  link_to work_order.id, admin_communication_work_order_path(work_order)
                when 'ExpressReceiptWorkOrder'
                  link_to work_order.id, admin_express_receipt_work_order_path(work_order)
                else
                  "##{work_order.id} (类型: #{work_order.type})"
                end
              end
              column "工单类型", :type
              column "工单状态" do |work_order|
                status_tag work_order.status if work_order.status.present?
              end
              column "关联报销单" do |work_order|
                if work_order.reimbursement
                  link_to work_order.reimbursement.invoice_number, admin_reimbursement_path(work_order.reimbursement)
                end
              end
              column "创建时间", :created_at
            end
          else
            para "此费用明细当前未关联任何工单。"
          end
        end
      end
    end
  end

  form do |f|
    f.inputs "费用明细信息" do
      f.input :document_number, as: :select, collection: Reimbursement.all.pluck(:invoice_number), include_blank: true
      f.input :external_fee_id
      f.input :fee_type
      f.input :amount, input_html: { min: 0.01 }
      f.input :fee_date, as: :datepicker
      f.input :verification_status, as: :select, collection: ["pending", "problematic", "verified"], include_blank: false
      f.input :month_belonging
      f.input :first_submission_date, as: :datepicker
      f.input :plan_or_pre_application
      f.input :product
      f.input :flex_field_6
      f.input :flex_field_7
      f.input :expense_corresponding_plan
      f.input :expense_associated_application
      f.input :notes
    end
    f.actions
  end
end