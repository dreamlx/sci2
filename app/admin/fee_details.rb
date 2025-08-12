ActiveAdmin.register FeeDetail do
  actions :index, :show, :edit, :update, :create, :new
  
  # 允许附件参数
  permit_params :document_number, :fee_type, :amount, :fee_date,
                :verification_status, :notes, :external_fee_id,
                :month_belonging, :first_submission_date, :plan_or_pre_application,
                :product, :flex_field_6, :flex_field_7, :expense_corresponding_plan,
                :expense_associated_application, attachments: []
  
  # 启用批量操作功能
  config.batch_actions = true
  
  # 控制器配置
  controller do
    def create
      super do |success, failure|
        success.html do
          # 如果是从报销单页面创建的附件，重定向回报销单详情页
          if params[:fee_detail][:document_number].present?
            reimbursement = Reimbursement.find_by(invoice_number: params[:fee_detail][:document_number])
            if reimbursement
              redirect_to admin_reimbursement_path(reimbursement), notice: '附件上传成功！'
              return
            end
          end
          # 默认重定向到费用明细详情页
          redirect_to admin_fee_detail_path(resource), notice: '费用明细创建成功！'
        end
      end
    end
  end
  
  # 添加一个简单的批量操作
  batch_action :mark_as_verified do |ids|
    batch_action_collection.find(ids).each do |fee_detail|
      fee_detail.update(verification_status: 'verified')
    end
    redirect_to collection_path, notice: "已将选中的费用明细标记为已验证"
  end
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
  
  # 添加弹性字段过滤器
  filter :flex_field_11, as: :string, label: "弹性字段11"
  filter :flex_field_6, as: :string, label: "弹性字段6(报销单)"
  filter :flex_field_7, as: :string, label: "弹性字段7(报销单)"
  
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
        "如果费用明细已存在（根据费用id判断）且报销单号相同，将更新现有记录",
        "如果费用明细已存在但报销单号不同，将更新费用明细的报销单号（前提是新报销单号存在于系统中）",
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
      notice_message += " #{result[:reimbursement_number_updated]} 报销单号已更新." if result[:reimbursement_number_updated].to_i > 0
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
    
    # 添加 UTF-8 BOM，以便 Excel 正确识别 UTF-8 编码
    bom = "\xEF\xBB\xBF"
    csv_data = bom + csv_data
    
    send_data csv_data,
              type: 'text/csv; charset=utf-8; header=present',
              disposition: "attachment; filename=费用明细_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
  end

  index do
    selectable_column
    id_column
    column "报销单号", :document_number do |fee_detail|
      if fee_detail.reimbursement
        link_to fee_detail.document_number, admin_reimbursement_path(fee_detail.reimbursement)
      else
        fee_detail.document_number
      end
    end
    column :fee_type
    column "金额", :amount do |fee_detail|
      number_to_currency(fee_detail.amount, unit: "¥")
    end
    column "验证状态", :verification_status do |fee_detail|
      status_tag fee_detail.verification_status
    end
    column "关联工单" do |fee_detail|
      latest_wo = fee_detail.latest_associated_work_order
      if latest_wo
        link_to "##{latest_wo.id}", [:admin, latest_wo]
      else
        "无"
      end
    end
    
    column "问题类型" do |fee_detail|
      latest_wo = fee_detail.latest_associated_work_order
      if latest_wo && latest_wo.problem_types.any?
        problem_details = latest_wo.problem_types.map do |problem_type|
          "#{problem_type.code}-#{problem_type.title}-#{problem_type.sop_description}+#{problem_type.standard_handling}"
        end.join("\n")
        
        content_tag(:pre, problem_details,
          class: "problem-type-plain-text",
          style: "white-space: pre-wrap; margin: 0; font-family: monospace; font-size: 12px;")
      else
        "无"
      end
    end
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
          row "弹性字段11" do |fee_detail|
            fee_detail.flex_field_11.presence || "未设置"
          end
          row "弹性字段6(报销单)" do |fee_detail|
            fee_detail.flex_field_6.presence || "未设置"
          end
          row "弹性字段7(报销单)" do |fee_detail|
            fee_detail.flex_field_7.presence || "未设置"
          end
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
      
      tab "附件信息 (#{resource.attachment_count})" do
        panel "附件列表" do
          if resource.attachments.attached?
            div class: "attachments-grid", style: "display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; margin: 20px 0;" do
              resource.attachments.each do |attachment|
                div class: "attachment-item", style: "border: 1px solid #ddd; padding: 15px; border-radius: 5px;" do
                  div style: "margin-bottom: 10px;" do
                    if attachment.image?
                      image_tag attachment.variant(resize_to_limit: [200, 200]),
                               style: "max-width: 100%; height: auto; border-radius: 3px;"
                    else
                      div style: "text-align: center; padding: 40px; background: #f5f5f5; border-radius: 3px;" do
                        case attachment.content_type
                        when 'application/pdf'
                          span "📄 PDF文档", style: "font-size: 24px;"
                        when /word/
                          span "📝 Word文档", style: "font-size: 24px;"
                        when /excel|sheet/
                          span "📊 Excel文档", style: "font-size: 24px;"
                        else
                          span "📎 文档", style: "font-size: 24px;"
                        end
                      end
                    end
                  end
                  
                  div do
                    strong attachment.filename.to_s
                  end
                  
                  div style: "color: #666; font-size: 12px; margin: 5px 0;" do
                    "大小: #{number_to_human_size(attachment.byte_size)}"
                  end
                  
                  div style: "color: #666; font-size: 12px; margin: 5px 0;" do
                    "类型: #{attachment.content_type}"
                  end
                  
                  div style: "margin-top: 10px;" do
                    link_to "下载", rails_blob_path(attachment, disposition: "attachment"),
                            class: "button small", style: "margin-right: 5px;"
                    if attachment.image?
                      link_to "预览", rails_blob_path(attachment),
                              class: "button small", target: "_blank"
                    end
                  end
                end
              end
            end
            
            div style: "margin-top: 20px; padding: 10px; background: #f0f8ff; border-radius: 5px;" do
              strong "附件统计："
              br
              span "总数量: #{resource.attachment_count}个"
              br
              span "总大小: #{number_to_human_size(resource.attachment_total_size)}"
              br
              span "类型分布: #{resource.attachment_types_summary}"
            end
          else
            para "该费用明细暂无附件", style: "text-align: center; color: #999; padding: 40px;"
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
    
    f.inputs "附件管理" do
      f.input :attachments, as: :file, input_html: {
        multiple: true,
        accept: "image/*,.pdf,.doc,.docx,.xls,.xlsx",
        class: "attachment-upload"
      }, hint: "支持图片、PDF、Word、Excel文件，单个文件最大10MB"
      
      if f.object.persisted? && f.object.attachments.attached?
        div class: "current-attachments" do
          h4 "当前附件："
          ul do
            f.object.attachments.each do |attachment|
              li do
                if attachment.image?
                  image_tag attachment.variant(resize_to_limit: [100, 100]),
                           style: "max-width: 100px; margin-right: 10px;"
                end
                span attachment.filename.to_s
                span " (#{number_to_human_size(attachment.byte_size)})"
                link_to "下载", rails_blob_path(attachment, disposition: "attachment"),
                        class: "button small", style: "margin-left: 10px;"
              end
            end
          end
        end
      end
    end
    
    f.actions
  end
end